require 'unit_test_helpers'
require 'functional_test_helpers'
require 'integration_test_helpers'

module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:
      class << self
        def inherited_with_rails_test_helpers(subclass) #:nodoc:
          case subclass.name
          when "ActiveSupport::TestCase" then subclass.send(:include, UnitTestHelpers)
          when "ActionController::TestCase" then subclass.send(:include, FunctionalTestHelpers)
          when "ActionController::IntegrationTest" then subclass.send(:include, IntegrationTestHelpers)
          end
          inherited_without_rails_test_helpers(subclass)
        end
        alias_method_chain :inherited, :rails_test_helpers
      end
    end
  end
end