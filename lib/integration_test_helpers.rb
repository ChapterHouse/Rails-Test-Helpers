require 'delayed_fixtures'
require 'rexml/document'

# Comming soon, hopefully.
module IntegrationTestHelpers

  def self.included(base) #:nodoc:
    class << base
      def default_values
        resolve_delayed_fixtures const_get(:DefaultValues)
      end
    end

    base.method(:include).call(DelayedFixtures)
#    base.method(:fixtures).call(:users)

  end

end