module DelayedFixtures #:nodoc:

  # This class is used to implement delayed fixture values.
  # Specifically, during class definition and within class methods, the fixtures aren't yet loaded.
  # As a consequence, fixture helpers are also not available.
  # Delayed fixtures allow for the delay of the evaluation of the fixture helpers until after the fixtures are loaded.
  # Method calls on a fixture is also allowed. This is accomplished by intercepting the method calls and replaying them
  # later once the fixture is available. To attempt to resolve the value of the delayed fixture, use the _resolve method.
  #
  # Note: The majority of the testing helpers will automatically resolve DelayedFixtures without an explicit call to _resolve.
  #
  # Example:
  #
  #   class UserTest < ActiveSupport::TestCase
  # 
  #     ConstantName = users(:joe).name.reverse
  #
  #     def test_something
  #       assert_equal ConstantName._resolve, users(:joe).name.reverse
  #     end
  #  
  #   end
  class DelayedFixture
  
    attr_accessor :_delayed_fixture_value_fixture
    attr_accessor :_delayed_fixture_value_name
    attr_accessor :_delayed_fixture_value_meth
    
    # Create a new delayed fixture. Pass the name of the fixture group and the name of the fixture within the group.
    # Meth should not be specified as it is used internally to connect ot the original fixture helper method.
    #
    # Example:
    #
    #   joe = DelayedFixture.new("user", "joe")
    # 
    def initialize(fixture, name, meth=nil)
      @_delayed_fixture_value_fixture = fixture
      @_delayed_fixture_value_name = name
      @_delayed_fixture_value_meth = meth
      @chain = []
    end
   
    # Attempts to resolve the value of the delayed fixture. If the fixtures have not been loaded then this returns self.
    # Otherwise it will attempt to locate the fixture and call all of the requested methods on it.
    #
    # Note: The majority of the testing helpers will automatically resolve DelayedFixtures without an explicit call to _resolve.
    #
    # Example:
    #
    #  joe = DelayedFixture.new("user", "joe").name.reverse
    #  joe._resolve #=> eoj
    def _resolve
      if _delayed_fixture_value_meth.nil?
        self
      else
        @chain.inject(_delayed_fixture_value_meth.call(_delayed_fixture_value_name)) { |rc, chain| rc.send(chain.first, *chain.last) }
      end
    end
  
    undef_method(:id)
    
    def method_missing(name, *args) #:nodoc:
      if _delayed_fixture_value_meth.nil?
        df = DelayedFixture.new(_delayed_fixture_value_fixture, _delayed_fixture_value_name)
        _chain.each { |command| df._add_to_chain(command.first, command.last) }
        df._add_to_chain name, args
        df
      else
        _resolve.send(name, *args)
      end
    end
  
    protected

    def _chain #:nodoc:
      @chain
    end
    
    def _add_to_chain(name, args) #:nodoc:
      @chain << [name, args]
    end
    
  end

  # A convenience method for creating a DelayedFixtureString.
  # A DelayedFixtureString is a string that contains one or more internal evaluations of DelayedFixtures.
  # The easiest way to create one is to use the helper method at ClassMethods#delayed_string.
  class DelayedFixtureString
    
    attr_accessor :_delayed_string
    attr_accessor :_delayed_src
    attr_accessor :_delayed_binding
    attr_accessor :_delayed_dependencies
    
    # Creates a new DelayedString.
    # It takes the string containing DelayedFixtures, an object to bind to that understands DelayedFixtures, and an array of the DelayedFixtures the string relies on for evaluation.
    # It is more common to use the helper in ClassMethods than to call new directly.
    #
    # Example:
    #
    #   class ModelTest < ActiveSupport::TestCase
    #  
    #     Person = people(:joe)
    #     Place = places(:stadium)
    #     Thing = things(:baseball)
    #     Action = DelayedString.new('#{Person.name} went to #{Place.name} at #{Place.address} and found a #{Thing.name}.', ModelTest, Person, Place, Thing)
    # 
    #     def test_something
    #       assert_equal "Joe Blow went to Gnats Stadium at 123 Main Street and found a baseball.', Action._resolve
    #     end
    #   end
    def initialize(string, bind, *dependencies)
      @_delayed_string = string
      @_delayed_binding = bind
      @_delayed_dependencies = dependencies.select { |x| x.is_a?(DelayedFixture) }
      @chain = []
    end
   
    # Attempts to resolve the value of the string containing delayed fixtures. If the fixtures have not been loaded then this returns self.
    # Otherwise it will try to evaluate the final value of the string.
    #
    # Note: The majority of the testing helpers will automatically resolve DelayedFixtureStrings without an explicit call to _resolve.
    #
    # Example:
    #
    #   class ModelTest < ActiveSupport::TestCase
    #  
    #     Person = people(:joe)
    #     Place = places(:stadium)
    #     Thing = things(:baseball)
    #     Action = DelayedString.new('#{Person.name} went to #{Place.name} at #{Place.address} and found a #{Thing.name}.', ModelTest, Person, Place, Thing)
    # 
    #     def test_something
    #       assert_equal "Joe Blow went to Gnats Stadium at 123 Main Street and found a baseball.', Action._resolve
    #     end
    #   end
    def _resolve
      @_delayed_dependencies = @_delayed_binding.send(:resolve_delayed_fixtures, @_delayed_dependencies)
      if @_delayed_dependencies.any? { |x| x.is_a?(DelayedFixture) }
        self
      else
        @chain.inject(@_delayed_binding.class_eval('"' + @_delayed_string + '"')) { |rc, chain| rc.send(chain.first, *chain.last) }
      end
    end
  
    undef_method(:id)
    
    def method_missing(name, *args) #:nodoc:
      if _delayed_fixture_value_meth.nil?
        df = DelayedFixture.new(_delayed_fixture_value_fixture, _delayed_fixture_value_name)
        _chain.each { |command| df._add_to_chain(command.first, command.last) }
        df._add_to_chain name, args
        df
      else
        _resolve.send(name, *args)
      end
    end
  
    protected

    def _chain #:nodoc:
      @chain
    end
    
    def _add_to_chain(name, args) #:nodoc:
      @chain << [name, args]
    end
    
  end

  module ClassMethods
    #Private hash of the delay fixtures we are ready to accept.
    #The first instance of this class will provide method binding values.
    #Those values allow for calling of the convenience fixture functions outside of an instance of this class.
    @@delayed_fixtures = {}

    
    def delayed_fixtures #:nodoc:
      @@delayed_fixtures
    end

    #Catch unknown class level method calls. Relay fixture convenience methods to delayed fixtures.
    def method_missing(name, *args) #:nodoc:
      if delayed_fixtures.has_key?(name)
        DelayedFixture.new(name, *args)
      else
        raise NoMethodError, "undefined method `#{name}' for #{name}:#{self.class.name}", caller
      end
    end
    
    #Intercept the fixture calls so we can record them and make the convenience methods available at the class level.
#      def fixtures_with_delayed_fixtures(*args)
#        args.each { |fixture| delayed_fixtures[fixture.to_sym] = nil }
#        fixtures_without_delayed_fixtures(*args)
#      end
#      alias_method_chain :fixtures, :delayed_fixtures

    fixtures_path = File.join(RAILS_ROOT, "test", "fixtures")
    table_names = Dir["#{fixtures_path}/*.yml"] + Dir["#{fixtures_path}/*.csv"]
    table_names.map! { |f| File.basename(f).split('.')[0..-2].join('.') }
    table_names.each { |fixture| @@delayed_fixtures[fixture.to_sym] = nil }
    
    def resolve_delayed_fixtures(values) #:nodoc:
      if values.is_a?(Hash)
        values.inject({}) do |hash, item|
          hash[item.first] = delayed_fixture_value(item.last)
          hash
        end
      elsif values.respond_to?(:map) && !values.is_a?(String)
        values.map { |value| delayed_fixture_value(value) }
      else
        delayed_fixture_value(values)
      end
    end

    def delayed_fixture_value(value) #:nodoc:
      if value.is_a?(DelayedFixture)
        value._delayed_fixture_value_meth = delayed_fixtures[value._delayed_fixture_value_fixture]
        value = value._resolve
      elsif value.is_a?(DelayedFixtureString)
        value = value._resolve
      end
      value
    end

    # A convenience method for creating a DelayedFixtureString.
    # It takes the string containing DelayedFixtures and an array of the DelayedFixtures it relies on for evaluation.
    # It assumes a binding of self.
    #
    # Example:
    #
    #  class ModelTest < ActiveSupport::TestCase
    #    Person = people(:joe)
    #    Place = places(:stadium)
    #    Thing = things(:baseball)
    #    Action = delayed_string('#{Person.name} went to #{Place.name} at #{Place.address} and found a #{Thing.name}.', Person, Place, Thing)
    # 
    #    def test_something
    #      assert_equal "Joe Blow went to Gnats Stadium at 123 Main Street and found a baseball.', Action._resolve
    #    end
    #  end
    def delayed_string(string, *dependencies)
      DelayedFixtures::DelayedFixtureString.new(string, self, *dependencies)
    end
  end
  
  def self.included(base) #:nodoc:

    class << base
      include ClassMethods
    end

  end

  private


  def delayed_fixtures
    self.class.delayed_fixtures
  end
  
  def prepare_delayed_fixtures
    delayed_fixtures.each_key { |key| delayed_fixtures[key] = method(key) } if delayed_fixtures.has_value?(nil)
  end

  def resolve_delayed_fixtures(values)
    prepare_delayed_fixtures
    self.class.resolve_delayed_fixtures values
  end

end






