require 'shellwords'

module Termpix
  module Protocols
    # Kitty Graphics Protocol
    module Kitty
      def self.display(image_path, x:, y:, max_width:, max_height:)
        dimensions = get_dimensions(image_path)
        return unless dimensions

        img_w, img_h = dimensions
        img_w, img_h = scale_dimensions(img_w, img_h, max_width, max_height)

        # Position cursor and display image
        print "\e[#{y};#{x}H"
        # Transmit image using Kitty protocol
        print "\e_Gf=100,a=T,t=f,c=#{img_w},r=#{img_h};#{[File.read(image_path)].pack('m0')}\e\\"
      end

      def self.clear
        print "\e_Ga=d\e\\"
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

        # Position cursor
        print "\e[#{y};#{x}H"
        # Convert to sixel and display
        system("convert #{escaped} -resize #{max_width}x#{max_height} sixel:- 2>/dev/null")
      end

      def self.clear
        print "\e[2J"
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

        # Get image dimensions
        escaped = Shellwords.escape(image_path)
        dimensions = `identify -format "%wx%h" #{escaped}[0] 2>/dev/null`.strip
        return if dimensions.empty?

        img_w, img_h = dimensions.split('x').map(&:to_i)

        # Scale if needed
        if img_w > img_max_w || img_h > img_max_h
          scale_w = img_max_w.to_f / img_w
          scale_h = img_max_h.to_f / img_h
          scale = [scale_w, scale_h].min
          img_w = (img_w * scale).to_i
          img_h = (img_h * scale).to_i
        end

        # Display using w3mimgdisplay protocol
        `echo '0;1;#{img_x};#{img_y};#{img_w};#{img_h};;;;;#{image_path}
4;
3;' | #{@imgdisplay} 2>/dev/null`
      end

      def self.clear
        system('clear')
        terminfo = `xwininfo -id $(xdotool getactivewindow 2>/dev/null) 2>/dev/null`
        return unless terminfo && !terminfo.empty?

        term_w = terminfo.match(/Width: (\d+)/)[1].to_i
        term_h = terminfo.match(/Height: (\d+)/)[1].to_i
        cols = `tput cols`.to_i
        lines = `tput lines`.to_i
        char_w = term_w / cols
        char_h = term_h / lines

        # Clear the image area
        `echo "6;0;0;#{term_w};#{term_h};\n4;\n3;" | #{@imgdisplay} 2>/dev/null`
      end
    end
  end
end
