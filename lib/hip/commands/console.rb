# frozen_string_literal: true

require_relative "../command"

module Hip
  module Commands
    module Console
      class Start < Hip::Command
        def execute
          puts script
        end

        private

        def script
          <<-SH.gsub(/^ {12}/, "")
            export HIP_SHELL=1
            export HIP_EARLY_ENVS=#{ENV.keys.join(",")}
            export HIP_PROMPT_TEXT="⦒"

            function hip_clear() {
              # just stub, will be redefined after injecting aliases
              true
            }

            function hip_inject() {
              eval "$(#{Hip.bin_path} console inject)"
            }

            function hip_reload() {
              hip_clear
              hip_inject
            }

            # Inspired by RVM
            function __zsh_like_cd() {
              \\typeset __zsh_like_cd_hook
              if
                builtin "$@"
              then
                for __zsh_like_cd_hook in chpwd "${chpwd_functions[@]}"
                do
                  if \\typeset -f "$__zsh_like_cd_hook" >/dev/null 2>&1
                  then "$__zsh_like_cd_hook" || break # finish on first failed hook
                  fi
                done
                true
              else
                return $?
              fi
            }

            [[ -n "${ZSH_VERSION:-}" ]] ||
            {
              function cd()    { __zsh_like_cd cd    "$@" ; }
              function popd()  { __zsh_like_cd popd  "$@" ; }
              function pushd() { __zsh_like_cd pushd "$@" ; }
            }

            export -a chpwd_functions
            [[ " ${chpwd_functions[*]} " == *" hip_reload "* ]] || chpwd_functions+=(hip_reload)

            if [[ "$ZSH_THEME" = "agnoster" ]]; then
              eval "`declare -f prompt_end | sed '1s/.*/_&/'`"

              function prompt_end() {
                if [[ -n $HIP_PROMPT_TEXT ]]; then
                  prompt_segment magenta white "$HIP_PROMPT_TEXT"
                fi

                _prompt_end
              }
            fi

            hip_reload
          SH
        end
      end

      class Inject < Hip::Command
        attr_reader :out, :aliases

        def initialize
          @aliases = []
          @out = []
        end

        def execute
          if Hip.config.exist?
            add_aliases(*Hip.config.interaction.keys) if Hip.config.interaction
            add_aliases("compose", "up", "stop", "down", "provision", "build")
          end

          clear_aliases

          puts out.join("\n\n")
        end

        private

        def add_aliases(*names)
          names.each do |name|
            aliases << name
            out << "function #{name}() { #{Hip.bin_path} #{name} $@; }"
          end
        end

        def clear_aliases
          out << "function dip_clear() { \n" \
                  "#{aliases.any? ? aliases.map { |a| "  unset -f #{a}" }.join("\n") : "true"} " \
                  "\n}"
        end
      end
    end
  end
end
