require 'delayed_fixtures'

# Unless you are writing your own specialized test you probably are looking for the helpers in FunctionalTestHelpers::ClassMethods.
#
# This module provides basic functional level test helpers to test the various aspects of a controller.
# It provides the basic building blocks for the test helpers in FunctionalTestHelpers::ClassMethods.
# These instance level methods can also be used to build new tests when the tests fall outside of the domain covered by the main test helpers.
# All of the helpers rely on a definition of a DefaultValue at the test class level. This is to be a hash of attribute value pairs that match the model.
#
# Example:
#
# class ItemsControllerTest < ActionController::TestCase
#
#   DefaultValues =  {
#     :name => "Some Name",
#     :location => "123 Main",
#     :color => "Blue"
#   }
#
# end
module FunctionalTestHelpers

  # This module provides basic functional level test helpers to test the various aspects of a controller.
  # Many of these tests will correspond to the standard actions that rails places in a controller.
  # The tests will automatically log in and log out of the application as needed unless instructed not to.
  # If these helpers do not cover a required test that falls outside of the standard patterns, you can leverage the underlying test helper instance methods in #FunctionalTestHelpers and build your own.
  # All of the helpers rely on a definition of a DefaultValue at the test class level. This is to be a hash of attribute value pairs that match the model.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     DefaultValues =  {
  #       :name => "Some Name",
  #       :location => "123 Main",
  #       :color => "Blue"
  #     }
  #
  #     use_defaults
  #
  #     test_index
  #     test_new
  #     test_create
  #     test_show
  #     test_edit
  #     test_update :name => 'Sum Name'
  #     test_destroy
  #     test_shouldnt_create :name => nil
  #     test_shouldnt_update :name => nil
  #
  #   end
  module ClassMethods

    # Returns whether or not this is a singleton resource. The default is nil.
    # To define that a resource is a singleton, declare the constant SingletonResource as true in your test class.
    # Alternately you can use the singleton_resource= method as well.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     SingletonResource true
    #
    #     def self.the_current_singleton_setting
    #       singleton_resource # => true
    #     end
    #
    #   end
    def singleton_resource
      const_defined?(:SingletonResource) ? const_get(:SingletonResource) : @singleton_resource
    end

    # Defines the tested resource as a singleton. The default is nil.
    # Normally this is done by setting the constant SingletonResource to true in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     singleton_resource = true
    #
    #   end
    def singleton_resource=(new_value)
      @singleton_resource = new_value unless const_defined?(:SingletonResource)
    end

    # Returns the default values to be used in tests. The default values are declared as a constant hash
    # with the name DefaultValues in the test class.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     def self.default_name
    #       default_values[:name]  #=> "Some Name"
    #     end
    #
    #   end
    def default_values
      resolve_delayed_fixtures const_get(:DefaultValues)
    end

    # Returns the model representing the users of the application. The default is User.
    # To change the model used either set the constant UserModel to the correct model in your test class
    # or use the user_model= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     UserModel = Plebeian
    #
    #     def self.the_model_is
    #       user_model  #=> Plebeian
    #     end
    #
    #   end
    def user_model(*args)
      if args.blank?
        const_defined?(:UserModel) ? const_get(:UserModel) : (@user_model || User)
      else
        self.user_model = args.first
      end
    end
    
    # Sets the model representing the users of the application. The default is User.
    # Normally this is done by setting the constant UserModel to the correct model in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     user_model = Plebeian
    #
    #   end
    def user_model=(new_value)
      @user_model = new_value unless const_defined?(:UserModel)
      @users_fixture_loaded = false
      load_users_fixture
    end

    # Returns the symbol for the user model of the test. The default is determined from the user_model.
    # To change the target either set the constant UserSymbol to the correct symbol in your test class
    # or use the user_symbol= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.the_symbol_of_the_people
    #       user_symbol  #=> :user
    #     end
    #
    #   end
    def user_symbol(*args)
      if args.blank?
        const_defined?(:UserSymbol) ? const_get(:UserSymbol) : (@user_symbol || user_model.name.tableize.singularize.to_sym)
      else
        self.target = args.first
      end
    end
    
    # Sets the symbol for the user model of the test. The default is determined from the user_model.
    # Normally this is done by setting the constant UserSymbol to the correct symbol in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     user_symbol = :plebeian
    #
    #   end
    def user_symbol=(new_value)
      @user_symbol = new_value unless const_defined?(:UserSymbol)
    end

    # Loads the fixtures for the users if they have not already been loaded.
    # The fixtures to be loaded are determined from the user_symbol.
    def load_users_fixture
      unless @users_fixture_loaded
        self.method(:fixtures).call(user_symbol.to_s.pluralize.to_sym)
        @users_fixture_loaded = true
      end
    end
    
    # Create the test setup method that defines the controller, request, and response instance variables. Then login to the application.
    # To skip the login, pass the symbol :without_login or a hash value of :without_login => true.
    # If you need to do additional steps before or after the setup, use the :prefix hash value. This will
    # prefix the method name with the string passed. Then you can call this generated method anywhere in your
    # own setup method. All other parameters will be passed to #FunctionalTestHelpers#login. If you are going to use both the default_setup and default_teardown see use_defaults.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     default_setup
    #
    #   end
    #
    # or
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     default_setup :without_login
    #
    #   end
    def default_setup(*args)
      options = args.last.is_a?(Hash) ? args.last.dup : {}
      args.each { |arg| options[arg] = true if arg.is_a?(Symbol) }
      method_name = "#{options[:prefix]}setup".to_sym
      unless options[:without_login]
        load_users_fixture
        define_method(method_name) do
          @controller = self.class.target.new
          @request    = ActionController::TestRequest.new
          @response   = ActionController::TestResponse.new
          login options
        end
      else
        define_method(method_name) do
          @controller = self.class.target.new
          @request    = ActionController::TestRequest.new
          @response   = ActionController::TestResponse.new
        end
      end
    end
    
    # Logoff the user after the test unless the :without_login symbol or :without_login => true hash value is passed.
    # If the :without_login parameter is used, an empty teardown will still be generated.
    # If you need to do additional steps before or after the teardown, use the :prefix hash value. This will
    # prefix the method name with the string passed. Then you can call this generated method anywhere in your
    # own teardown method. If you are going to use both the default_setup and default_teardown see use_defaults.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     default_teardown
    #
    #   end
    def default_teardown(*args)
      options = args.last.is_a?(Hash) ? args.last.dup : {}
      args.each { |arg| options[arg] = true if arg.is_a?(Symbol) }
      method_name = "#{options[:prefix]}teardown".to_sym
      unless options[:without_login]
        define_method(method_name) { logout options }
      else
        define_method(method_name) {}
      end
    end

    # Returns whether or not the resource being tested is a singleton resource.
    # If the singularity has not been expressly set by the constant SingletonResource or the method single_resource=
    # then this method will attempt to dynamically determine if the resource is a singleton by comparing the 
    # singular resource name against the plural. If they match then the resource is considered a singleton. Obviously
    # in the case of irregular nouns like "sheep" this will be incorrect. In that case, explicitly set the singleton to false.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.am_I_alone?
    #       singleton_resource? #=> false
    #     end
    #
    #   end
    def singleton_resource?
      tester_klass = name.classify.constantize
      if tester_klass.singleton_resource.nil?
        if name[0..-15] != name[0..-15].pluralize
          tester_klass.singleton_resource = true
        else
          tester_klass.singleton_resource = false
        end
      end
      tester_klass.singleton_resource
    end
          
    # Returns the target of the test. The default is determined from the name of the test. Thus, ItemsControllerTest becomes ItemsController.
    # To change the target either set the constant Target to the correct controller in your test class
    # or use the target= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_am_I_testing
    #       target #=> ItemsController
    #     end
    #
    #   end
    def target(*args)
      if args.blank?
        const_defined?(:Target) ? const_get(:Target) : (@target || name[0..-5].classify.constantize)
      else
        self.target = args.first
      end
    end
    
    # Sets the target of the test. The default is determined from the name of the test. Thus, ItemsControllerTest becomes ItemsController.
    # Normally this is done by setting the constant Target to the correct controller in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target = ThingsController
    #
    #   end
    def target=(new_value)
      @target = new_value unless const_defined?(:Target)
    end

    # Returns the model that accompanies the controller target of the test. The default is determined from the target. Thus, ItemsController becomes Item.
    # To change the target model either set the constant TargetModel to the correct model in your test class
    # or use the target_model= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_model_am_I_using
    #       target_model #=> Item
    #     end
    #
    #   end
    def target_model(*args)
      if args.blank?
        const_defined?(:TargetModel) ? const_get(:TargetModel) : (@target_model || target.name[0..-11].classify.constantize)
      else
        self.target_model = args.first
      end
    end
    
    # Sets the model that accompanies the controller target of the test. The default is determined from the target. Thus, ItemsController becomes Item.
    # Normally this is done by setting the constant TargetModel to the correct model in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target_model = Thing
    #
    #   end
    def target_model=(new_value)
      @target_model = new_value unless const_defined?(:TargetModel)
    end

    # Returns the human readable name that is used in error messages. The default is determined from the target_model.
    # To change the target name either set the constant TargetName to the correct name in your test class
    # or use the target_name= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_name_am_I_using
    #       target_name #=> "Item"
    #     end
    #
    #   end
    def target_name(*args)
     if args.blank?
        (const_defined?(:TargetName) ? const_get(:TargetName) : (@target_name || target_model.name.underscore.titleize)).to_s
      else
        self.target_name = args.first
      end
    end
    
    # Sets the human readable name that is used in error messages. The default is determined from the target_model.
    # Normally this is done by setting the constant TargetName to the correct model in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target_name = "Some Special Thing"
    #
    #   end
    def target_name=(new_value)
      @target_name = new_value unless const_defined?(:TargetName)
    end
  
    # Returns the human readable plural name that is used in error messages. The default is determined from the target_name.
    # To change the target name either set the constant TargetNamePlural to the correct plural name in your test class
    # or use the target_name= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_plural_name_am_I_using
    #       target_name #=> "Items"
    #     end
    #
    #   end
    def target_name_plural(*args)
      if args.blank?
        (const_defined?(:TargetNamePlural) ? const_get(:TargetNamePlural) : (@target_name_plural || target_name.pluralize)).to_s
      else
        self.target_name_plural = args.first
      end
    end
    
    # Sets the human readable plural name that is used in error messages. The default is determined from the target_name.
    # Normally this is done by setting the constant TargetNamePlural to the correct plural name in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target_plural_name = "Some Special Things"
    #
    #   end
    def target_name_plural=(new_value)
      @target_name_plural = new_value unless const_defined?(:TargetNamePlural)
    end
  
    # Returns the symbol name that is used for parameter and assigns checks. The default is determined from the target_model.
    # To change the target name either set the constant TargetSymbol to the correct symbol in your test class
    # or use the target_name= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_parameter_am_I_using
    #       target_symbol #=> :item
    #     end
    #
    #   end
    def target_symbol(*args)
      if args.blank?
        (const_defined?(:TargetSymbol) ? const_get(:TargetSymbol) : (@target_symbol || target_model.name.underscore)).to_sym
      else
        self.target_symbol = args.first
      end
    end
    
    # Sets the symbol name that is used for parameter and assigns checks. The default is determined from the target_model.
    # Normally this is done by setting the constant TargetSymbol to the correct symbol in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target_symbol = :thingamabob
    #
    #   end
    def target_symbol=(new_value)
      @target_symbol = new_value unless const_defined?(:TargetSymbol)
    end
  
    # Returns the plural symbol name that is used for parameter and assigns checks. The default is determined from the target_symbol.
    # To change the target name either set the constant TargetSymbolPlural to the correct symbol in your test class
    # or use the target_name= method. The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     def self.what_plural_parameter_am_I_using
    #       target_symbol #=> :items
    #     end
    #
    #   end
    def target_symbol_plural(*args)
      if args.blank?
        (const_defined?(:TargetSymbolPlural) ? const_get(:TargetSymbolPlural) : (@target_symbol_plural || target_symbol.to_s.pluralize)).to_sym
      else
        self.target_symbol_plural = args.first
      end
    end
    
    # Sets the plural symbol name that is used for parameter and assigns checks. The default is determined from the target_symbol.
    # Normally this is done by setting the constant TargetSymbolPlural to the correct symbol in your test class.
    # However, if for some reason that is not feasible, you may use this setter.
    # The constant definition takes presence over the attribute.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     target_symbol_plural = :thingamabobs
    #
    #   end
    def target_symbol_plural=(new_value)
      @target_symbol_plural = new_value unless const_defined?(:TargetSymbolPlural)
    end

    # Test for standard resource creation using the default values and any additional value hashes given.
    # Each additional hash will be merged with the default values and will result in additional creation checks.
    # The expected redirect after each creation is also checked. If the location is different from the standard, then
    # use the :redirect_to hash value to specify the new desired location.
    # The following example will attempt to create two seperate resources that are only different in color.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_create :color => "Red"
    #
    #   end
    def test_create(*values_hashes)
      values_hashes.unshift default_values
      define_method("test_should_create_#{target_symbol}".to_sym) do
        values_hashes.each do |values_hash|
          assert_kind_of Hash, values_hash, "Cannot test with a #{values_hash.class.name}. Hashes are required. Value given: #{values_hash.inspect}"
          values_hash = resolve_delayed_fixtures(default_values.merge(values_hash))
          old_count = target_model.count if target_model.respond_to?(:count)
          post :create, target_symbol => values_hash
          assert_equal old_count+1, target_model.count, "Failed to create a #{target_name} with #{values_hash.inspect}." if target_model.respond_to?(:count)
          redirect_target = values_hash.delete(:redirect_to) { send("#{target_symbol}_path".to_sym, assigns(target_symbol)) }
          assert_redirected_to redirect_target
        end
      end
    end

    # Test for standard resource destruction using the ids or fixture names given. If nothing is given, the fixture labeled :one will be used.
    # The count of the remaining object will be checked.
    # By default this is expected to be one less than what was present before. This can be changed by passing a hash value for :difference. 
    # The expected redirect after each creation is also checked. If the location is different from the standard, then
    # use the :redirect_to hash value to specify the new desired location.
    # Arrays can also be used to specify the id, difference, and redirection.
    # The following example will attempt to destroy six seperate resources. Two of them expect differences other than 1.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_destroy :this_one, 5, {:id => :that_one, :difference => 8}, 3, [:another, 4], items(:last_one).id
    #
    #   end
    def test_destroy(*ids_and_counts)
      ids_and_counts.push :one if ids_and_counts.empty?
      ids_and_counts.map! do |idc|
        idc = case idc
          when Array then [idc.first || :one, idc[1] || 1, idc[2]]
          when Hash then [idc[:id] || :one, idc[:difference] || 1, idc[:redirect_to]]
          else [idc, 1, nil]
        end
        idc[0] = send(target_model.name.tableize.to_sym, idc[0]).id if idc.first.is_a?(Symbol)
        idc
      end
      define_method("test_should_destroy_#{target_symbol}".to_sym) do
        ids_and_counts.each do |idc|
          id, count_difference, redirect_target = idc
          original_id = original_id.is_a?(Symbol) ? "#{original_id.inspect} " : ""
          id = resolve_delayed_fixtures(id)
          redirect_target = send("#{target_symbol_plural}_path".to_sym) unless redirect_target
          old_count = target_model.count if target_model.respond_to?(:count)
          delete :destroy, :id => id
          expected_count = old_count - count_difference if target_model.respond_to?(:count)
          assert_equal expected_count, target_model.count, "Failed to properly destroy #{target_name} #{original_id}(id: #{id}). Expected #{expected_count} items remaining. Found #{target_model.count} instead." if target_model.respond_to?(:count)
          assert_redirected_to redirect_target, "Failed to destroy #{target_name} #{original_id}with id #{id}."
        end
      end
    end
    
    # Test for standard resource edit form using the ids or fixture names given. If nothing is given, the fixture labeled :one will be used.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_edit :this_one, :that_one, 5, 7, 1, 3, :another, items(:last_one).id
    #
    #   end
    def test_edit(*ids)
      ids.push :one if ids.empty?
      original_ids = ids.dup
      ids.map! { |id| id.is_a?(Symbol) ? send(target_model.name.tableize.to_sym, id).id : id }
      define_method("test_should_get_edit_#{target_symbol}".to_sym) do
        ids.each_with_index do |id, i|
          original_id = original_ids[i].is_a?(Symbol) ? "#{original_ids[i].inspect} " : ""
          id = resolve_delayed_fixtures(id)
          error_message = "Could not edit #{target_name} #{original_id}with id #{id}."
          get :edit, :id => id
          assert_response :success, error_message
        end
      end
    end

    # Test for standard index retrieval and instance variable assignment.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_index
    #
    #   end
    def test_index
      define_method("test_should_get_#{target_symbol_plural}_index".to_sym) do
        get :index
        assert_response :success#, "Failed to get #{target_name} index."
        unless singleton_resource?
          assert assigns.has_key?(target_symbol_plural.to_s), "@#{target_symbol_plural} was not assigned in the index."
        else
          assert assigns.has_key?(target_symbol.to_s), "@#{target_symbol} was not assigned in the index."
        end
      end
    end
    
    # Test for standard new resource prototype using the default values and any additional value hashes given.
    # Each additional hash will be merged with the default values and will result in additional prototype checks.
    # The following example will attempt to prototype two seperate resources that are only different in color.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_new :color => "Red"
    #
    #   end
    def test_new(*values_hashes)
      values_hashes.unshift default_values
      define_method("test_should_get_new_#{target_symbol}".to_sym) do
        values_hashes.each do |values_hash|
          assert_kind_of Hash, values_hash, "Cannot test with a #{values_hash.class.name}. Hashes are required. Value given: #{values_hash.inspect}"
          values_hash = resolve_delayed_fixtures(default_values.merge(values_hash))
          get :new, values_hash
          assert_response :success, "Failed to get a new #{target_name} with values #{values_hash.inspect}."
        end
      end
    end
    
    # Test for standard resource retrieval using the ids or fixture names given. If nothing is given, the fixture labeled :one will be used.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_show :this_one, :that_one, 5, 7, 1, 3, :another, items(:last_one).id
    #
    #   end
    def test_show(*ids)
      ids.push :one if ids.empty?
      original_ids = ids.dup
      ids.map! { |id| id.is_a?(Symbol) ? send(target_model.name.tableize.to_sym, id).id : id }
      define_method("test_should_show_#{target_symbol}".to_sym) do
        ids.each_with_index do |id, i|
          original_id = original_ids[i].is_a?(Symbol) ? "#{original_ids[i].inspect} " : ""
          id = resolve_delayed_fixtures(id)
          error_message = "Could not show #{target_name} #{original_id}with id #{id}."
          get :show, :id => id
          assert_response :success, error_message
        end
      end
    end

    # Test for standard resource update using the value hashes given.
    # Each hash will will result in additional update checks.
    # The fixture labeled :one will be the the resource updated. If a different resource is desired, pass an :id hash value.
    # The expected redirect after each update is also checked.
    # If the location is different from the standard, then use the :redirect_to hash value to specify the new desired location.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_update :name => "Sum Name"
    #
    #   end
    def test_update(*changed_values_hashes)
      define_method("test_should_update_#{target_symbol}".to_sym) do
        assert changed_values_hashes.size > 0, "Must provide at least one hash of values to test with."
        changed_values_hashes.each do |changed_values_hash|
          assert_kind_of Hash, changed_values_hash, "Cannot test with a #{changed_values_hash.class.name}. Hashes are required. Value given: #{changed_values_hash.inspect}"
          values = resolve_delayed_fixtures(changed_values_hash)
          original_id = values.delete(:id) { :one } 
          if original_id.is_a?(Symbol)
            id = send(target_model.name.tableize.to_sym, original_id).id
            original_id = "#{original_id.inspect} "
          else
            id = original_id
            original_id = ""
          end
          id = resolve_delayed_fixtures(id)
          post :update, :id => id, target_symbol => values
          assert assigns(target_symbol), "Update failed to assign @#{target_symbol} when updating #{target_name} #{original_id}(id: #{id}) with #{values.inspect}."
          if singleton_resource?
            redirect_target = changed_values_hash.delete(:redirect_to) { send("#{target_symbol}_path".to_sym) }
            assert_redirected_to redirect_target, "Failed to update a #{target_name} #{original_id}(id: #{id}) with #{values.inspect}."
          else
            redirect_target = changed_values_hash.delete(:redirect_to) { send("#{target_symbol}_path".to_sym, assigns(target_symbol)) }
            assert_redirected_to redirect_target, "Failed to update a #{target_name} #{original_id}(id: #{id}) with #{values.inspect}."
          end
        end
      end
    end

    # Test for standard resource creation failure using the value hashes given..
    # Each hash given will be merged with the default values and will result in additional creation failure checks.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_shouldnt_create :name => nil
    #
    #   end
    def test_shouldnt_create(*bad_values_hashes)
      define_method("test_shouldnt_create_#{target_symbol}".to_sym) do
        assert bad_values_hashes.size > 0, "Must provide at least one hash of values to test with."
        bad_values_hashes.each do |bad_values_hash|
          assert_kind_of Hash, bad_values_hash, "Cannot test with a #{bad_values_hash.class.name}. Hashes are required. Value given: #{bad_values_hash.inspect}"
          values = resolve_delayed_fixtures(default_values.merge(bad_values_hash))
          required_response = values.delete(:assert) { :success }
          old_count = target_model.count if target_model.respond_to?(:count)
          post :create, target_symbol => values
          assert_equal old_count, target_model.count, "Should not have created a #{target_name} with #{values.inspect}." if target_model.respond_to?(:count)
          assert_response required_response
        end
      end
    end

    # Test for standard resource update failure using the value hashes given.
    # Each hash will will result in additional update checks.
    # The fixture labeled :one will be the the resource updated. If a different resource is desired, pass an :id hash value.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     DefaultValues =  {
    #       :name => "Some Name",
    #       :location => "123 Main",
    #       :color => "Blue"
    #     }
    #
    #     use_defaults
    #
    #     test_update :name => nil
    #
    #   end
    def test_shouldnt_update(*bad_values_hashes)
      define_method("test_shouldnt_update_#{target_symbol}".to_sym) do
        assert bad_values_hashes.size > 0, "Must provide at least one hash of values to test with."
        bad_values_hashes.each do |bad_values_hash|
          assert_kind_of Hash, bad_values_hash, "Cannot test with a #{bad_values_hash.class.name}. Hashes are required. Value given: #{bad_values_hash.inspect}"
          values = resolve_delayed_fixtures(bad_values_hash)
          id = values.delete(:id) { send(target_model.name.tableize.to_sym, :one).id }
          required_response = values.delete(:assert) { :success }
          old_values = target_model.find(id)
          post :update, :id => id, target_symbol => values
          assert_equal old_values, target_model.find(id), "Should not have updated a #{target_name} (id: #{id}) with #{values.inspect}."
          assert_response required_response
        end
      end
    end
    
    # Shortcut for specifying both default_setup and default_teardown. Arguments will be passed to both methods.
    #
    # Example:
    #
    #   class ItemsControllerTest < ActionController::TestCase
    #
    #     use_defaults :without_login
    #
    #   end
    def use_defaults(*args)
      default_setup(*args)
      default_teardown(*args)
    end
  end
  
  def self.included(base) #:nodoc:

    class << base
      include ClassMethods
    end

    base.method(:include).call(ActionController::UrlWriter)
    base.method(:include).call(DelayedFixtures)
    base.method(:include).call(AuthenticatedTestHelper)
#    base.method(:fixtures).call(:users)

  end
  
  # Returns the default values to be used in tests. The default values are declared as a constant hash
  # with the name DefaultValues in the test class.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     DefaultValues =  {
  #       :name => "Some Name",
  #       :location => "123 Main",
  #       :color => "Blue"
  #     }
  #
  #     def default_name
  #       default_values[:name]  #=> "Some Name"
  #     end
  #
  #   end
  def default_values
    resolve_delayed_fixtures self.class.default_values
  end

  # Returns the model representing the users of the application.
  # See #ClassMethods#user_model for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     UserModel = Plebeian
  #
  #     def the_user_model_is
  #       user_model  #=> Plebeian
  #     end
  #
  #   end
  def user_model
    self.class.user_model    
  end
  
  # Returns the symbol for the user model of the test.
  # See #ClassMethods#user_symbol for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def the_symbol_of_the_people
  #       user_symbol  #=> :user
  #     end
  #
  #   end
  def user_symbol
    self.class.user_symbol    
  end

  # Loads the fixtures for the users if they have not already been loaded.
  # The fixtures to be loaded are determined from the user_symbol.
  def load_users_fixture
    self.class.load_users_fixture
  end

  # Login to the application for testing. Accepts a hash containing values for :login, :password, and :starting_url.
  # After logging in, a redirect is expected and checked against the :starting_url.
  # If :starting_url is not given, it defaults to '/'.
  # If :password is not given it defaults to 'test'.
  # If :login is not given, it will first look to see if you have passed an instance of your user model using the
  # user_symbol as the key. If that is not found, it defaults to the fixture test_<user_symbol>. ie: test_user.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     UserModel = Plebeian
  #
  #     def test_various_logins_and_logouts
  #       login
  #       logout
  #       login :login => "joe"
  #       logout
  #       login :plebeian => plebeians(:lucy)
  #       logout
  #       login :login => "goofball", :password => 'ickyicky", :starting_url => '/home/goofball'
  #       logout
  #     end
  #
  #   end
  # 
  def login(options={})
    options = resolve_delayed_fixtures(options)

    user = options[user_symbol]
    login = options.fetch(:login, user ? user.login : "test_#{user_symbol.to_s}")
    password = options.fetch(:password, 'test')
    starting_url = options.fetch(:starting_url, '/')

    with_controller(SessionsController) do
      post :create, {:login => login, :password => password}
      assert_redirected_to starting_url
    end
  end

  # Logout to the application after testing. Accepts a hash containing a value for :ending_url.
  # After logging out, a redirect is expected and checked against the :ending_url.
  # If :ending_url is not given, it defaults to '/'.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     UserModel = Plebeian
  #
  #     def test_varous_logins_and_logouts
  #       login
  #       logout
  #       login :login => "goofball"
  #       logout :ending_url => '/fine_be_that_way'
  #     end
  #
  #   end
  # 
  def logout(options={})
    with_controller(SessionsController) do
      redirect_target = options.fetch(:ending_url, "/")
      post :destroy
      assert_redirected_to redirect_target
    end
  end

  # Returns whether or not the resource being tested is a singleton resource.
  # See #ClassMethods#singleton_resource? for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def am_I_alone?
  #       singleton_resource? #=> false
  #     end
  #
  #   end
  def singleton_resource?
    self.class.singleton_resource?
  end
  
  # Sets the model that accompanies the controller target of the test.
  # See #ClassMethods#target_model for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     target_model = Thing
  #
  #     def the_model_is
  #       target_model  #=> Thing
  #     end
  #
  #   end
  def target_model
    self.class.target_model
  end

  # Returns the human readable name that is used in error messages.
  # See #ClassMethods#target_name for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def what_name_am_I_using
  #       target_name #=> "Item"
  #     end
  #
  #   end
  def target_name
    self.class.target_name
  end

  # Returns the human readable plural name that is used in error messages.
  # See #ClassMethods#target_name_plural for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def what_plural_name_am_I_using
  #       target_name #=> "Items"
  #     end
  #
  #   end
  def target_name_plural
    self.class.target_name_plural
  end

  # Returns the symbol name that is used for parameter and assigns checks.
  # See #ClassMethods#target_symbol for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def what_parameter_am_I_using
  #       target_symbol #=> :item
  #     end
  #
  #   end
  def target_symbol
    self.class.target_symbol
  end

  # Returns the plural symbol name that is used for parameter and assigns checks.
  # See #ClassMethods#target_symbol_plural for more details.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def what_plural_parameter_am_I_using
  #       target_symbol #=> :items
  #     end
  #
  #   end
  def target_symbol_plural
    self.class.target_symbol_plural
  end

  # Execute a block with a different controller. Restores the original controller upon completion.
  # Returns the result of the block.
  #
  # Example:
  #
  #   class ItemsControllerTest < ActionController::TestCase
  #
  #     def test_something_with_another_controller
  #
  #       with_controller(OtherController) do
  #         post :create  # Create a new Other resource
  #       end
  #       post :create  # Then create a new Item resource
  #
  #     end
  #
  #   end
  def with_controller(controller_class, &block)
    old_controller = @controller
    @controller = controller_class.new
    rc = yield(controller_class)
    @controller = old_controller
    rc
  end

end