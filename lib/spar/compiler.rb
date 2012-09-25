require 'fileutils'
require 'find'

module Spar
  module Compiler

    def self.assets
      assets = []
      Spar.sprockets.each_logical_path do |logical_path|
        next unless compile_info = path_compile_info(logical_path)
        if asset = Spar.sprockets.find_asset(logical_path)
          assets << Spar::CompiledAsset.new(asset, compile_info)
        end
      end
      Dir.chdir(Spar.root) do
        Find.find('public').each do |path|
          if FileTest.directory?(path)
            if File.basename(path)[0] == '..'
              Find.prune # Don't look any further into this directory.
            else
              next
            end
          else
            if File.basename(path) == '.DS_Store'
              next
            else
              assets << Spar::CompiledAsset.new(path)
            end
          end
        end
      end
      assets
    end

    def self.path_compile_info(logical_path)
      if logical_path =~ /\.html/
        return {
          :digest         => false, 
          :cache_control  => 'no-cache'
        }
      elsif logical_path =~ /\w+\.(?!js|css).+/
        return {
          :digest         => Spar.settings['digests'], 
          :cache_control  => Spar.settings['cache_control']
        }
      elsif file_path = Spar.sprockets.resolve(logical_path)
        file = File.open(file_path, "rb").read
        if header = file[Sprockets::DirectiveProcessor::HEADER_PATTERN, 0]
          if directive = header.lines.peek[Sprockets::DirectiveProcessor::DIRECTIVE_PATTERN, 1]
            name, *args = Shellwords.shellwords(directive)
            if name == 'compile'
              return compile_directive_info(*args)
            end
          end
        end
      end
      nil
    end

    def self.compile_directive_info(*args)
      options = {}
      args.each do |arg| 
        options[arg.split(':')[0]] = arg.split(':')[1]
      end
      {
        :digest         => Spar.settings['digests'],
        :cache_control  => options['cache_control'] || Spar.settings['cache_control']
      }
    end

  end
end
