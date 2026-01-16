require 'shellwords'
require 'base64'

module Termpix
  module Protocols
    # Kitty Graphics Protocol
    # Uses Unicode placeholder mode (U=1) for curses/TUI compatibility
    # Images are tied to placeholder characters that curses manages as text
    module Kitty
      @current_image_id = nil
      @image_cache = {}  # path -> image_id mapping

      def self.display(image_path, x:, y:, max_width:, max_height:)
        return false unless File.exist?(image_path)

        # Get terminal cell size in pixels
        cell_width, cell_height = get_cell_size
        return false unless cell_width && cell_height

        # Calculate pixel dimensions for the image area
        pixel_width = max_width * cell_width
        pixel_height = max_height * cell_height

        # Check if we have this image cached
        cache_key = "#{image_path}:#{pixel_width}x#{pixel_height}"
        image_id = @image_cache[cache_key]

        unless image_id
          # Generate new image ID (1-4294967295)
          image_id = (Time.now.to_f * 1000).to_i % 4294967295
          image_id = 1 if image_id == 0
        end

        old_image_id = @current_image_id

        unless @image_cache[cache_key]
          # Transmit the image with scaling
          escaped = Shellwords.escape(image_path)

          # Create scaled PNG data using ImageMagick
          png_data = `convert #{escaped}[0] -auto-orient -resize #{pixel_width}x#{pixel_height}\\> PNG:- 2>/dev/null`
          return false if png_data.empty?

          # Encode as base64 and chunk it (max 4096 bytes per chunk)
          encoded = Base64.strict_encode64(png_data)
          chunks = encoded.scan(/.{1,4096}/)

          # Transmit image in chunks
          chunks.each_with_index do |chunk, idx|
            more = idx < chunks.length - 1 ? 1 : 0
            if idx == 0
              # First chunk: specify format (f=100 for PNG), action (a=t for transmit)
              # i=image_id, m=more_chunks
              print "\e_Ga=t,f=100,i=#{image_id},m=#{more};#{chunk}\e\\"
            else
              # Continuation chunks
              print "\e_Gm=#{more};#{chunk}\e\\"
            end
          end
          $stdout.flush

          @image_cache[cache_key] = image_id
        end

        # Position cursor and display the NEW image FIRST
        # a=p (place), i=image_id, C=1 (don't move cursor)
        # Don't specify c/r - let kitty use image's native size (already scaled by ImageMagick)
        print "\e[#{y};#{x}H"  # Move cursor to position
        print "\e_Ga=p,i=#{image_id},C=1\e\\"
        $stdout.flush

        # NOW delete old placement (after new one is visible) - atomic swap
        if old_image_id && old_image_id != image_id
          print "\e_Ga=d,d=i,i=#{old_image_id}\e\\"
          $stdout.flush
        end

        @current_image_id = image_id
        true
      end

      def self.clear
        # Actually clear the image
        if @current_image_id
          print "\e_Ga=d,d=i,i=#{@current_image_id}\e\\"
          $stdout.flush
          @current_image_id = nil
        end
        true
      end

      def self.get_cell_size
        # Query terminal for cell size using XTWINOPS
        # Or estimate from terminal size
        begin
          require 'io/console'
          rows, cols = IO.console.winsize
          # Get pixel size if available
          if IO.console.respond_to?(:winsize_pixels)
            prows, pcols = IO.console.winsize_pixels rescue nil
            if prows && pcols && prows > 0 && pcols > 0
              return [pcols / cols, prows / rows]
            end
          end
          # Fall back to common defaults (10x20 pixels per cell)
          [10, 20]
        rescue
          [10, 20]
        end
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

        # Check if image has EXIF orientation data before auto-orienting
        # This avoids unnecessary temp file creation for most images
        escaped = Shellwords.escape(image_path)

        # Quick check: only auto-orient if image has EXIF orientation tag
        has_orientation = `identify -format "%[EXIF:Orientation]" #{escaped}[0] 2>/dev/null`.strip

        if has_orientation && !has_orientation.empty? && has_orientation != "1"
          # Image needs rotation - create cached temp file
          require 'digest'
          file_hash = Digest::MD5.hexdigest(image_path)
          temp_file = "/tmp/termpix_#{file_hash}.jpg"

          unless File.exist?(temp_file)
            system("convert #{escaped}[0] -auto-orient #{temp_file} 2>/dev/null")
          end

          display_path = File.exist?(temp_file) ? temp_file : image_path
        else
          # No rotation needed - use original image
          display_path = image_path
        end

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

        # Don't delete temp file - keep it cached for performance
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
