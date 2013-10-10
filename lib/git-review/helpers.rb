module GitReview

  module Helpers

    private

    # System call to 'git'
    def git_call(command, verbose = debug_mode, enforce_success = false)
      if verbose
        puts
        puts "  git #{command}"
        puts
      end

      output = `git #{command}`
      puts output if verbose and not output.empty?

      if enforce_success and not command_successful?
        puts output unless output.empty?
        raise ::GitReview::UnprocessableState
      end

      output
    end

    # @return [Boolean] Whether the last issued system call was successful
    def command_successful?
      $?.exitstatus == 0
    end

    # @return [Boolean] Whether we are running in debugging moder or not
    def debug_mode
      ::GitReview::Settings.instance.review_mode == 'debug'
    end

  end

end
