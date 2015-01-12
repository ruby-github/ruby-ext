module Image
  module Capture
    module_function

    def capture name, x, y, width, height, logger = nil
      dir = File.dirname name

      if not File.mkdir dir, logger
        return false
      end

      Dir.chdir dir do
        begin
          file = Java.import('java.io.File').new File.basename(name).utf8.strip
          rectangle = Java.import('java.awt.Rectangle').new x, y, width, height
          image = Java.import('java.awt.Robot').new.createScreenCapture rectangle

          Java.import('javax.imageio.ImageIO').write image, 'png', file

          true
        rescue
          if logger
            logger.exception $!
          end

          false
        end
      end
    end

    def desktop name, logger = nil
      begin
        screen_size = Java.import('java.awt.Toolkit').getDefaultToolkit.screen_size
      rescue
        if logger
          logger.exception $!
        end

        return false
      end

      capture name, 0, 0, screen_size.width, screen_size.height, logger
    end
  end

  module Image
    module_function

    def rename old_name, new_name, logger = nil
      if not File.file? old_name
        return false
      end

      image = nil

      Dir.chdir File.dirname(old_name) do
        begin
          file = Java.import('java.io.File').new File.basename(old_name).utf8.strip
          image = Java.import('javax.imageio.ImageIO').read file
        rescue
          if logger
            logger.exception $!
          end

          return false
        end
      end

      if image.nil?
        return false
      end

      dir = File.dirname new_name

      if not File.mkdir dir, logger
        return false
      end

      Dir.chdir dir do
        begin
          file = Java.import('java.io.File').new File.basename(new_name).utf8.strip
          Java.import('javax.imageio.ImageIO').write image, File.extname(new_name)[1..-1].utf8.strip.downcase, file
        rescue
          if logger
            logger.exception $!
          end

          return false
        end
      end

      if not File.file? new_name
        return false
      end

      if not File.same_path? old_name, new_name, true
        if File.same_path? File.dirname(old_name), dirname, true
          if not File.delete old_name, logger
            return false
          end
        end
      end

      true
    end
  end
end