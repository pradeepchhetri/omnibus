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
require 'fileutils'

module Omnibus
  class Licenses
    include Logging

    OUTPUT_DIRECTORY = "LICENSES".freeze

    class << self
      # @see (Licenses#create!)
      def create!(project)
        new(project).create!
      end
    end

    #
    # The project to healthcheck.
    #
    # @return [Project]
    #
    attr_reader :project

    #
    # Creates the license files for given project.
    # It is assumed that the project has already been built.
    #
    # @param [Project] project
    #   the project to create licenses for.
    #
    def initialize(project)
      @project = project
    end

    #
    # Creates the license files for given project.
    #
    def create!
      prepare
      create_software_license_files
      create_project_license_file
    end

    #
    # Creates the required directories for licenses.
    #
    def prepare
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end

    #
    # Creates the top level license file(s) for the project.
    #
    def create_project_license_file
      File.open(project.license_file_path, 'w') do |f|
        f.puts "#{project.name} #{project.build_version}"
        f.puts ""
        f.puts project_license_content
        f.puts ""
        f.puts components_license_summary
      end
    end

    #
    # Copies the license files specified by the software components into the
    # output directory.
    #
    def create_software_license_files
      license_map.each do |name, values|
        license_files = values[:license_files]

        license_files.each do |license_file|
          if license_file && is_local(license_file)
            input_file = File.expand_path(license_file, values[:project_dir])
            output_file = license_package_location(name, license_file)
            FileUtils.cp(input_file, output_file)
          end
        end
      end
    end

    #
    # Contents of the project's license
    #
    def project_license_content
      project.license_file.nil? ? "" : IO.read(project.license_file)
    end

    #
    # Summary of the licenses included by the softwares of the project.
    #
    def components_license_summary
      out = "\n\n"

      license_map.keys.sort.each do |name|
        license = license_map[name][:license]
        license_files = license_map[name][:license_files]
        version = license_map[name][:version]

        out << "This product bundles #{name} #{version},\n"
        out << "which is available under a \"#{license}\" License.\n"
        out << "For details, see:\n"
        license_files.each do |license_file|
          out << "#{license_package_location(name, license_file)}\n"
        end
        out << "\n"
      end

      out
    end

    #
    # Map that collects information about the licenses of the softwares
    # included in the project.
    #
    def license_map
      @license_map ||= begin
        map = {}

        project.library.each do |component|
          # Some of the components do not bundle any software but contain
          # some logic that we use during the build. These components are
          # covered under the project's license and they do not need specific
          # license files.
          next if component.license == :project_license

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

    #
    # Returns the location where the license file should reside in the package.
    #
    def license_package_location(component_name, where)
      if is_local(where)
        File.join(output_dir, "#{component_name}-#{File.split(where).last}")
      else
        where
      end
    end

    #
    # Output directory to create the licenses in.
    #
    def output_dir
      File.expand_path(OUTPUT_DIRECTORY, project.install_dir)
    end

    #
    # Returns if the given path to a license is local or a remote url.
    #
    def is_local(license)
      u = URI(license)
      return u.scheme.nil?
    end
  end
end
