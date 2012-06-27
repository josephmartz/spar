require 'fileutils'
require 'rack/test'

module Spar
  class StaticCompiler

    VIEW_PATH_SPLITER = /(.*)\/([^\/]+?)/

    attr_accessor :app, :env, :asset_path, :paths

    def self.load_tasks
      Dir[File.expand_path('../tasks/spar.rake', __FILE__)].each { |ext| load ext }
    end

    def initialize(app, options = {})
      @app        = app
      @env        = app.asset_env
      @public_path = app.public_path
      @asset_path = File.join(app.public_path, app.asset_prefix)
      @paths      = App.asset_precompile
      @digest     = app.asset_digest
      @zip_files  = options.delete(:zip_files) || /\.(?:css|html|js|svg|txt|xml)$/
      @view_paths = app.precompile_view_paths || []
    end

    def compile
      manifest = {}
      @env.each_logical_path do |logical_path|
        next unless compile_path?(logical_path)
        if asset = @env.find_asset(logical_path)
          manifest[logical_path] = write_asset(asset)
        end
      end
      write_manifest(manifest)
      browser = Rack::Test::Session.new(Rack::MockSession.new(@app))
      @view_paths.each do |path|
        browser.get(path)
        write_view(path, browser.last_response.body)
      end
    end

    def write_manifest(manifest)
      FileUtils.mkdir_p(@asset_path)
      File.open("#{@asset_path}/manifest.yml", 'wb') do |f|
        YAML.dump(manifest, f)
      end
    end

    def write_view(path, body)
      path = File.join(@public_path,path)
      FileUtils.mkdir_p path
      File.open(File.join(path,"index.html"), 'wb') do |f|
        f.write(body)
      end
    end

    def write_asset(asset)
      path_for(asset).tap do |path|
        filename = File.join(asset_path, path)
        FileUtils.mkdir_p File.dirname(filename)
        asset.write_to(filename)
        # Use "example.txtgz" instead of "example.txt.gz" for Safari gzip workaround.
        asset.write_to("#{filename}gz") if filename.to_s =~ @zip_files
      end
    end

    def compile_path?(logical_path)
      @paths.each do |path|
        case path
        when Regexp
          return true if path.match(logical_path)
        when Proc
          return true if path.call(logical_path)
        else
          return true if File.fnmatch(path.to_s, logical_path)
        end
      end
      false
    end

    def path_for(asset)
      @digest ? asset.digest_path : asset.logical_path
    end
  end
end
