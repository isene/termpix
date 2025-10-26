require_relative 'termpix/version'
require_relative 'termpix/protocols'

module Termpix
  class Display
    attr_reader :protocol

    def initialize(protocol: nil)
      @protocol = protocol || detect_protocol
      @current_image = nil
    end

    # Display an image at the specified position
    # @param image_path [String] Path to the image file
    # @param x [Integer] X position in terminal characters
    # @param y [Integer] Y position in terminal characters
    # @param max_width [Integer] Maximum width in terminal characters
    # @param max_height [Integer] Maximum height in terminal characters
    def show(image_path, x: 0, y: 0, max_width: 80, max_height: 24)
      return false unless @protocol
      return false unless File.exist?(image_path)

      case @protocol
      when :kitty
        Protocols::Kitty.display(image_path, x: x, y: y, max_width: max_width, max_height: max_height)
      when :sixel
        Protocols::Sixel.display(image_path, x: x, y: y, max_width: max_width, max_height: max_height)
      when :ueberzug
        Protocols::Ueberzug.display(image_path, x: x, y: y, max_width: max_width, max_height: max_height)
      when :w3m
        Protocols::W3m.display(image_path, x: x, y: y, max_width: max_width, max_height: max_height)
      else
        return false
      end

      @current_image = image_path
      true
    end

    # Clear the currently displayed image
    def clear(x: 0, y: 0, width: 80, height: 24, term_width: 80, term_height: 24)
      return false unless @protocol

      case @protocol
      when :kitty
        Protocols::Kitty.clear
      when :sixel
        Protocols::Sixel.clear
      when :ueberzug
        Protocols::Ueberzug.clear
      when :w3m
        Protocols::W3m.clear(x: x, y: y, width: width, height: height, term_width: term_width, term_height: term_height)
      end

      @current_image = nil
      true
    end

    # Check if image display is supported
    def supported?
      !@protocol.nil?
    end

    # Get information about the current protocol
    def info
      {
        protocol: @protocol,
        supported: supported?,
        current_image: @current_image
      }
    end

    private

    def detect_protocol
      # Check for Sixel support first - works better with curses apps
      # Note: urxvt/rxvt-unicode does NOT support sixel unless specially compiled
      # Kitty's sixel support doesn't work properly (shows ASCII) - use w3m instead
      if ENV['TERM']&.match(/^xterm(?!-kitty)|^mlterm|^foot/)
        return :sixel if check_dependency('convert')
      end

      # Kitty graphics protocol disabled - incompatible with curses apps
      # Kitty protocol needs full terminal control, conflicts with curses rendering
      # Users can choose between:
      # 1. Enable w3m for Kitty (has brief flash) - set TERMPIX_KITTY_USE_W3M=1
      # 2. No images in Kitty (clean UI)

      # Überzug++ - disabled for now (implementation incomplete)
      # TODO: Implement proper Überzug++ JSON-RPC communication
      # if command_exists?('ueberzug') || command_exists?('ueberzugpp')
      #   if check_dependencies('xwininfo', 'xdotool', 'identify')
      #     return :ueberzug
      #   end
      # end

      # Fall back to w3m (works everywhere but has brief flash in Kitty)
      if command_exists?('/usr/lib/w3m/w3mimgdisplay')
        if check_dependencies('xwininfo', 'xdotool', 'identify')
          return :w3m
        end
      end

      # No supported protocol found
      nil
    end

    def command_exists?(cmd)
      system("which #{cmd} > /dev/null 2>&1")
    end

    def check_dependency(cmd)
      command_exists?(cmd)
    end

    def check_dependencies(*cmds)
      cmds.all? { |cmd| command_exists?(cmd) }
    end
  end
end
