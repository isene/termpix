require 'shellwords'
require 'base64'

module Termpix
  module Protocols
    # Kitty Graphics Protocol
    # After extensive testing: Kitty protocol fundamentally incompatible with curses
    # The protocol requires precise cursor control that conflicts with curses' buffer
    # management. Recommend disabling Kitty protocol for curses-based apps.
    module Kitty
      def self.display(image_path, x:, y:, max_width:, max_height:)
        # Kitty graphics protocol does not work reliably with curses applications
        # The fundamental issue is that both Kitty and curses need exclusive control
        # of terminal state, causing unavoidable conflicts
        false
      end

      def self.clear
        true
      end

      private

      def self.get_dimensions(image_path)
        escaped = Shellwords.escape(image_path)
        dimensions = `identify -format "%wx%h" #{escaped}[0] 2>/dev/null`.strip
        return nil if dimensions.empty?
        dimensions.split('x').map(&:to_i)
      end

      def self.scale_dimensions(w, h, max_w, max_h)
        if w > max_w || h > max_h
          scale = [max_w.to_f / w, max_h.to_f / h].min
          w = (w * scale).to_i
          h = (h * scale).to_i
        end
        [w, h]
      end
    end

    # Sixel Protocol
    module Sixel
      def self.display(image_path, x:, y:, max_width:, max_height:)
        escaped = Shellwords.escape(image_path)

        # Convert character dimensions to approximate pixel dimensions
        # Average character cell is roughly 10x20 pixels in most terminals
        pixel_width = max_width * 10
        pixel_height = max_height * 20

        # Position cursor at the specified character position
        print "\e[#{y};#{x}H"
        # Use > to only shrink, never enlarge, preserving aspect ratio
        # ImageMagick will fit image within box while maintaining aspect ratio
        system("convert #{escaped} -resize #{pixel_width}x#{pixel_height}\\> sixel:- 2>/dev/null")
      end

      def self.clear
        # Sixel images are inline - they don't need explicit clearing
        # The terminal will handle this when content is redrawn
        # Don't use \e[2J as that clears the entire screen including curses content!
        true
      end
    end

    # Überzug++ Protocol
    module Ueberzug
      def self.display(image_path, x:, y:, max_width:, max_height:)
        # Get terminal pixel dimensions
        terminfo = `xwininfo -id $(xdotool getactivewindow 2>/dev/null) 2>/dev/null`
        return unless terminfo && !terminfo.empty?

        term_w = terminfo.match(/Width: (\d+)/)[1].to_i
        term_h = terminfo.match(/Height: (\d+)/)[1].to_i

        # Calculate character dimensions
        char_w = term_w / `tput cols`.to_i
        char_h = term_h / `tput lines`.to_i

        # Convert character positions to pixels
        img_x = char_w * x
        img_y = char_h * y
        img_w = char_w * max_width
        img_h = char_h * max_height

        # TODO: Implement actual Überzug++ protocol
        # For now, placeholder
      end

      def self.clear
        system('clear')
      end
    end

    # w3mimgdisplay Protocol
    module W3m
      @imgdisplay = '/usr/lib/w3m/w3mimgdisplay'

      def self.display(image_path, x:, y:, max_width:, max_height:)
        # Get terminal pixel dimensions
        terminfo = `xwininfo -id $(xdotool getactivewindow 2>/dev/null) 2>/dev/null`
        return unless terminfo && !terminfo.empty?

        term_w = terminfo.match(/Width: (\d+)/)[1].to_i
        term_h = terminfo.match(/Height: (\d+)/)[1].to_i

        # Calculate character dimensions
        cols = `tput cols`.to_i
        lines = `tput lines`.to_i
        char_w = term_w / cols
        char_h = term_h / lines

        # Convert to pixel coordinates
        img_x = char_w * x
        img_y = char_h * y
        img_max_w = char_w * max_width
        img_max_h = char_h * max_height

        # Handle EXIF orientation by creating auto-oriented temp file
        escaped = Shellwords.escape(image_path)
        temp_file = "/tmp/termpix_#{Process.pid}.jpg"

        # Auto-orient image to respect EXIF rotation, then get dimensions
        system("convert #{escaped}[0] -auto-orient #{temp_file} 2>/dev/null")
        display_path = File.exist?(temp_file) ? temp_file : image_path

        dimensions = `identify -format "%wx%h" #{Shellwords.escape(display_path)} 2>/dev/null`.strip
        return if dimensions.empty?

        img_w, img_h = dimensions.split('x').map(&:to_i)

        # Scale if needed - preserve aspect ratio
        if img_w > img_max_w || img_h > img_max_h
          scale_w = img_max_w.to_f / img_w
          scale_h = img_max_h.to_f / img_h
          scale = [scale_w, scale_h].min
          img_w = (img_w * scale).to_i
          img_h = (img_h * scale).to_i
        end

        # Display using w3mimgdisplay protocol
        `echo '0;1;#{img_x};#{img_y};#{img_w};#{img_h};;;;;#{display_path}
4;
3;' | #{@imgdisplay} 2>/dev/null`

        # Clean up temp file
        File.delete(temp_file) if File.exist?(temp_file) && temp_file != image_path
      end

      def self.clear(x:, y:, width:, height:, term_width:, term_height:)
        # Clear only the image overlay in the specified area
        terminfo = `xwininfo -id $(xdotool getactivewindow 2>/dev/null) 2>/dev/null`
        return true unless terminfo && !terminfo.empty?

        term_w = terminfo.match(/Width: (\d+)/)[1].to_i
        term_h = terminfo.match(/Height: (\d+)/)[1].to_i

        # Calculate character dimensions
        char_w = term_w / term_width
        char_h = term_h / term_height

        # Convert to pixel coordinates with slight margin adjustment
        img_x = (char_w * x) - char_w
        img_y = char_h * y
        img_max_w = (char_w * width) + char_w + 2
        img_max_h = char_h * height + 2

        # Use w3mimgdisplay command "6" to clear just the image area
        `echo "6;#{img_x};#{img_y};#{img_max_w};#{img_max_h};\n4;\n3;" | #{@imgdisplay} 2>/dev/null`
        true
      end
    end
  end
end
