# frozen_string_literal: true

require "rdoc/task"
require "rails/api/generator"

module Rails
  module API
    class Task < RDoc::Task
      RDOC_FILES = {
        "activesupport" => {
          include: %w(
            README.rdoc
            lib/active_support/**/*.rb
          )
        },

        "activerecord" => {
          include: %w(
            README.rdoc
            lib/active_record/**/*.rb
            lib/arel.rb
          )
        },

        "activemodel" => {
          include: %w(
            README.rdoc
            lib/active_model/**/*.rb
          )
        },

        "actionpack" => {
          include: %w(
            README.rdoc
            lib/abstract_controller/**/*.rb
            lib/action_controller/**/*.rb
            lib/action_dispatch/**/*.rb
          )
        },

        "actionview" => {
          include: %w(
            README.rdoc
            lib/action_view/**/*.rb
          ),
          exclude: "lib/action_view/vendor/*"
        },

        "actionmailer" => {
          include: %w(
            README.rdoc
            lib/action_mailer/**/*.rb
          )
        },

        "activejob" => {
          include: %w(
            README.md
            lib/active_job/**/*.rb
          )
        },

        "actioncable" => {
          include: %w(
            README.md
            lib/action_cable/**/*.rb
          )
        },

        "activestorage" => {
          include: %w(
            README.md
            app/**/active_storage/**/*.rb
            lib/active_storage/**/*.rb
          )
        },

        "actionmailbox" => {
          include: %w(
            README.md
            app/**/action_mailbox/**/*.rb
            lib/action_mailbox/**/*.rb
          )
        },

        "actiontext" => {
          include: %w(
            README.md
            app/**/action_text/**/*.rb
            lib/action_text/**/*.rb
          )
        },

        "railties" => {
          include: %w(
            README.rdoc
            lib/**/*.rb
          ),
          exclude: %w(
            lib/rails/generators/**/templates/**/*.rb
            lib/rails/test_unit/*
            lib/rails/api/generator.rb
          )
        }
      }

      def initialize(name)
        super

        # Every time rake runs this task is instantiated as all the rest.
        # Be lazy computing stuff to have as light impact as possible to
        # the rest of tasks.
        before_running_rdoc do
          configure_sdoc
          configure_rdoc_files
          setup_horo_variables
        end
      end

      # Hack, ignore the desc calls performed by the original initializer.
      def desc(description)
        # no-op
      end

      def configure_sdoc
        self.title    = "Ruby on Rails API"
        self.rdoc_dir = api_dir

        options << "-m"  << api_main
        options << "-e"  << "UTF-8"

        options << "-f"  << "api"
        options << "-T"  << "rails"
      end

      def configure_rdoc_files
        rdoc_files.include(api_main)

        RDOC_FILES.each do |component, cfg|
          cdr = component_root_dir(component)

          Array(cfg[:include]).each do |pattern|
            rdoc_files.include("#{cdr}/#{pattern}")
          end

          Array(cfg[:exclude]).each do |pattern|
            rdoc_files.exclude("#{cdr}/#{pattern}")
          end
        end

        # Only generate documentation for files that have been
        # changed since the API was generated.
        if Dir.exist?("doc/rdoc") && !ENV["ALL"]
          last_generation = DateTime.rfc2822(File.open("doc/rdoc/created.rid", &:readline))

          rdoc_files.keep_if do |file|
            File.mtime(file).to_datetime > last_generation
          end

          # Nothing to do
          exit(0) if rdoc_files.empty?
        end
      end

      # These variables are used by the sdoc template
      def setup_horo_variables # :nodoc:
        ENV["HORO_PROJECT_NAME"]    = "Ruby on Rails"
        ENV["HORO_PROJECT_VERSION"] = rails_version
        ENV["HORO_BADGE_VERSION"]   = badge_version
      end

      def api_main
        component_root_dir("railties") + "/RDOC_MAIN.rdoc"
      end
    end

    class RepoTask < Task
      def configure_sdoc
        super
        options << "-g" # link to GitHub, SDoc flag
      end

      def component_root_dir(component)
        component
      end

      def api_dir
        "doc/rdoc"
      end

      def version_options
        <<~VERSIONS
          <option value="https://api.rubyonrails.org/v7.0/" style="background-color: transparent;">v7.0</option>
          <option value="https://api.rubyonrails.org/v6.1/" style="background-color: transparent;">v6.1</option>
          <option value="https://api.rubyonrails.org/v6.0/" style="background-color: transparent;">v6.0</option>
          <option value="https://api.rubyonrails.org/v5.2/" style="background-color: transparent;">v5.2</option>
          <option value="https://api.rubyonrails.org/v5.1/" style="background-color: transparent;">v5.1</option>
          <option value="https://api.rubyonrails.org/v5.0/" style="background-color: transparent;">v5.0</option>
          <option value="https://api.rubyonrails.org/v4.2/" style="background-color: transparent;">v4.2</option>
          <option value="https://api.rubyonrails.org/v4.1/" style="background-color: transparent;">v4.1</option>
          <option value="https://api.rubyonrails.org/v4.0/" style="background-color: transparent;">v4.0</option>
          <option value="https://api.rubyonrails.org/v3.2/" style="background-color: transparent;">v3.2</option>
          <option value="https://api.rubyonrails.org/v3.1/" style="background-color: transparent;">v3.1</option>
          <option value="https://api.rubyonrails.org/v3.0/" style="background-color: transparent;">v3.0</option>
          <option value="https://api.rubyonrails.org/v2.3/" style="background-color: transparent;">v2.3</option>
        VERSIONS
      end
    end

    class EdgeTask < RepoTask
      def rails_version
        "main@#{`git rev-parse HEAD`[0, 7]}"
      end

      def badge_version
        <<~VERSION
        <select onchange="if (this.value) window.location.href=this.value" id="versions" style="appearance: none; background-color: transparent; font-family: inherit; font-size: 100%;font-weight: inherit; line-height: inherit;  color: inherit; margin: 0;padding: 0; border: none; ">
          <option value="https://edgeapi.rubyonrails.org" style="background-color: transparent;" selected>edge</option>
          <option value="https://api.rubyonrails.org/" style="background-color: transparent;" selected>latest</option>
          #{version_options}
        </select>
        VERSION
      end
    end

    class StableTask < RepoTask
      def rails_version
        File.read("RAILS_VERSION").strip
      end

      def badge_version
        <<~VERSIONS
        <select onchange="if (this.value) window.location.href=this.value" id="versions" style="appearance: none; background-color: transparent; font-family: inherit; font-size: 100%;font-weight: inherit; line-height: inherit;  color: inherit; margin: 0;padding: 0; border: none; ">
          <option value="https://edgeapi.rubyonrails.org" style="background-color: transparent;" selected>edge</option>
          <option value="https://api.rubyonrails.org/" style="background-color: transparent;">v#{rails_version}</option>
          #{version_options}
        </select>
        VERSIONS
      end
    end
  end
end
