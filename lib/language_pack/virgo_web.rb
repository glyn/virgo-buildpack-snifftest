require "language_pack/java"
require "fileutils"

# TODO logging
module LanguagePack
  class VirgoWeb < Java

    VIRGO_URL =  "http://virgo.eclipse.org.s3.amazonaws.com/virgo-tomcat-server-3.6.1.RELEASE.tar.gz".freeze
    WEBAPP_DIR = "pickup/app.war/".freeze

    def self.use?
      $stderr.puts "VirgoWeb self?.use entered"
      # Test for manifest in either original or compiled location
      result = File.exists?("META-INF/MANIFEST.MF") || File.exists?("#{WEBAPP_DIR}META-INF/MANIFEST.MF")
      $stderr.puts "VirgoWeb self?.use exiting"
      result
    end

    def name
      "Virgo Web"
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        install_virgo
        remove_virgo_files
        copy_webapp_to_virgo
        move_virgo_to_root
        copy_resources
        setup_profiled
      end
    end

    def install_virgo
      FileUtils.mkdir_p virgo_dir
      virgo_zip="#{virgo_dir}/virgo.zip"

      download_virgo virgo_zip

      puts "Unpacking Virgo to #{virgo_dir}"
      run_with_err_output("tar pxzf #{virgo_zip} -C #{virgo_dir} && mv #{virgo_dir}/virgo-*/* #{virgo_dir} && " +
              "rm -rf #{virgo_dir}/virgo-*")
      FileUtils.rm_rf virgo_zip
      unless File.exists?("#{virgo_dir}/bin/startup.sh")
        puts "Unable to retrieve Virgo"
        exit 1
      end
    end

    def download_virgo(virgo_zip)
      puts "Downloading Virgo: #{VIRGO_URL}"
      run_with_err_output("curl --silent --location #{VIRGO_URL} --output #{virgo_zip}")
    end

    def remove_virgo_files
      %w(notice.html epl-v10.html docs work [Aa]bout* pickup/org.eclipse.virgo.apps.*).each do |file|
        Dir.glob("#{virgo_dir}/#{file}") do |entry|
          FileUtils.rm_rf(entry)
        end
      end
    end

    def virgo_dir
      ".virgo"
    end

    def copy_webapp_to_virgo
      FileUtils.mkdir_p "#{virgo_dir}/#{WEBAPP_DIR}"
      run_with_err_output("mv * #{virgo_dir}/#{WEBAPP_DIR}.")
    end

    def move_virgo_to_root
      run_with_err_output("mv #{virgo_dir}/* . && rm -rf #{virgo_dir}")
    end

    def copy_resources
      # Configure server.xml with variable HTTP port
      run_with_err_output("cp -r #{File.expand_path('../../../resources/virgo', __FILE__)}/* #{build_path}")
    end

    def java_opts
      # TODO proxy settings?
      # Don't override Virgo's temp dir setting
      opts = super.merge({ "-Dhttp.port=" => "$VCAP_APP_PORT" })
      opts.delete("-Djava.io.tmpdir=")
      opts
    end

    def default_process_types
      {
        "web" => "./bin/startup.sh -clean"
      }
    end

  end
end