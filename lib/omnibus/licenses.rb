#
# Copyright 2012-2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'uri'

module Omnibus
  class Licenses
    include Logging

    attr_reader :project

    class << self
      # @see (Licenses#write!)
      def write!(project)
        new(project).write!
      end
    end

    def initialize(project)
      @project = project
    end

    def write!
      write_license_files
    end

    def license_list(project)
      licenses = project.library.license_map
      out = "\n\n"

      licenses.keys.sort.each do |name|
        license = licenses[name][:license]
        license_files = licenses[name][:license_files]
        version = licenses[name][:version]

        out << "This product bundles #{name} #{version},\n"
        out << "which is available under a \"#{license}\" License.\n"

        license_files.each do |license_file|
          out << "For details, see #{location(name, license_file)}\n"
        end
        out << "\n"
      end

      out
    end

    def location(name, where)
      u = URI(where)
      if u.scheme
        # Is a URI, just return it
        where
      else
        File.join(output_dir, "#{name}-#{File.split(where).last}")
      end
    end

    def output_dir
      "LICENSES"
    end

    #
    # Writes out all the various license related files - Top level
    # license file and also copies any package specific license
    # files into the package
    #
    def write_license_files
      copy_license_files
      write_license_file
    end

    def write_license_file
      File.open(license_file_path, 'w') do |f|
        f.puts "#{name} #{build_version}"
        f.puts ""
        f.puts license_text
        f.puts ""
        f.puts Omnibus::Licenses.license_list(self)
      end
    end

    def copy_license_files
      license_dir = File.expand_path(Omnibus::Licenses.output_dir, install_dir)

      FileUtils.mkdir_p(license_dir)
      library.license_map.each do |name, values|
        license_files = values[:license_files]
        license_files.each do |license_file|
          if license_file && is_local(license_file)
            input_file = File.expand_path(license_file, values[:project_dir])
            output_file = File.expand_path(Omnibus::Licenses.location(name, license_file), install_dir)
            FileUtils.cp(input_file, output_file)
          end
        end
      end
    end

    def license_map
      @components.reduce({}) do |map, component|
        ## Components without a version are
        ## pieces of the omnibus project
        ## itself, and so don't have a separate license
        if component.default_version
          map[component.name] = {
            license: component.license,
            license_files: component.license_files,
            version: component.version,
            project_dir: component.project_dir,
          }
        end
        map
      end
    end

    def is_local(license)
      u = URI(license)
      return u.scheme.nil?
    end

    def license_text
      if license_file
        IO.read(license_file)
      else
        ""
      end
    end
  end
end
