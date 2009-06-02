require 'delayed_fixtures'

# Unless you are writing your own specialized test you probably are looking for the helpers in UnitTestHelpers::ClassMethods.
#
# This module provides basic unit level test helpers to test the various aspects of a model.
# It provides the basic building blocks for the test helpers in UnitTestHelpers::ClassMethods.
# These instance level methods can also be used to build new tests when the tests fall outside of the domain covered by the main test helpers.
# All of the helpers rely on a definition of a DefaultValue at the test class level. This is to be a hash of attribute value pairs that match the model.
#
# Example:
#
#   class SomeModelTest < ActiveSupport::TestCase
#
#     DefaultValues =  {
#       :name => "Some Name",
#       :location => "123 Main",
#       :color => "Blue"
#     }
#
#   end
module UnitTestHelpers

  # This module provides basic unit level test helpers to test the various aspects of a model.
  # Many of these tests will correspond to the validations that are used in the model.
  # If a method takes multiple attributes as its parameter, then a test will be generated for each attribute given.
  # If these helpers do not cover a required test that falls outside of the standard patterns, you can leverage the underlying test helper instance methods in #UnitTestHelpers and build your own.
  # All of the helpers rely on a definition of a DefaultValue at the test class level. This is to be a hash of attribute value pairs that match the model.
  #
  # Example:
  #
  #  class SomeModelTest < ActiveSupport::TestCase
  #  
  #    DefaultValues =  {
  #      :name => "Some Name",
  #      :color => "Blue",
  #      :placement => "Ceiling", 
  #      :quantity => 7,
  #      :email => "foo@bar.baz"
  #    }
  #  
  #    test_create
  #    test_format_of :email
  #    test_inclusion_of :placement
  #    test_length_of :name => 3..100
  #    test_long :placement => 32
  #    test_numericality_of :quantity
  #    test_presence_of :name, :color, :placement, :quantity, :email
  #    test_short :color => 3
  #    test_uniqueness_of :email
  #    test_update :name => "Sum Name"
  #  
  #  end 
  module ClassMethods

    # Returns the target model of the test. This is determined by taking the current class name and removing the word 'Test' from the end of it. For example, PersonTest will assume that it is testing the Person model.
    def target
      Object.const_get(name[0..-5].to_sym)
    end
    
    # Returns the default values hash after resolving any delayed fixtures.
    # Analogous to the same method at the intance level in #UnitTestHelpers#default_values
    def default_values
      resolve_delayed_fixtures const_get(:DefaultValues)
    end
  
    # Tests that an instance of the model can be created and saved using the default values.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue"
    #   }
    #
    #   test_create
    def test_create
      define_method(:test_create) { check_create }
    end
  
    # Tests that an instance of the model can have the specified attributes updated and saved.
    # Then tests that each updated value can be retrieved back from the database.
    # A separate test will be run for each attribute name given. The following example would result in three separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue"
    #   }
    #
    #   test_update :name => "Sum Name", :color => "Bloo", :location => "123 Mane"
    def test_update(*args)
      hash = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |x| hash[x] = nil }
      hash.each do |item, value|
        define_method("test_update_of_#{item.to_s}".to_sym) { check_update item.to_sym => value }
      end
    end

    # Tests that a set of attributes is required to be present by the model. Best paired with validates_presence_of.
    # A separate test will be run for each attribute name given. The following example would result in three separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue"
    #   }
    #
    #   test_presence_of :name, :location, :color
    def test_presence_of(*args)
      args.each do |item|
        define_method("test_presence_of_#{item.to_s}".to_sym) { check_presence_of item.to_sym }
      end
    end
    
    # Tests that a set of attributes is required to be numeric by the model. Best paired with validates_numericality_of.
    # If no value is given, a non numeric value will be created by treating the default value as a string,
    # removing the last digit, and adding the letter 'z' to the beginning of the string.
    # A separate test will be run for each attribute given. The following example would result in three separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :quantity => 7,
    #     :rating => 9,
    #     :size => 3
    #   }
    #
    #   test_numericality_of :quantity, {:rating => 'none'}, [:size, 'abc']
    def test_numericality_of(*args)
      args.each do |item|
        if item.is_a?(Hash)
          name = item.keys.first
          value = item[name]
        elsif item.is_a?(Array)
          name = item[0]
          value = item[1]
        else
          name = item
          value = nil
        end
        define_method("test_numericality_of_#{name.to_s}".to_sym) { check_numericality_of name.to_sym, value }
      end
    end

    # Tests that a set of attributes is required to fit a certain format by the model. Best paired with validates_format_of.
    # The default value will be used to test against the format. Additionally you can provide valid and invalid values to test
    # with by giving a hash that contains an array of values in the <em>_:with_valid</em> and <em>:with_invalid</em> keys respectively.
    # A separate test will be run for each attribute given. The following example would result in three separate tests.
    # The first and last test only uses the default value to test with. The second test uses additional test values.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :email => "foo@bar.baz"
    #   }
    #
    #   test_format_of :location, :email, {:with_valid => 'xxx@example.com', :with_invalid => ['something other than email', 'cold not fun']}, :name
    #
    # The following would accomplish the same thing
    #
    #   test_format_of :name, :location
    #   test_format_of :email, :with_valid => 'xxx@example.com', :with_invalid => ['something other than email', 'cold not fun']
    def test_format_of(*args)
      args.each_with_index do |item, i|
        values = Hash.new { |hash, key| hash[key] = [] }
        i += 1
        while args[i].is_a?(Hash) || args[i].is_a?(Array)
          args[i] = {:with_valid => args[i]} if args[i].is_a?(Array)
          args[i].each do |key, test_values|
            test_values = [test_values] unless test_values.is_a?(Array)
            test_values.each { |value| values[key] << value }
          end
          i+= 1
        end
        
        define_method("test_format_of_#{item.to_s}".to_sym) do
          check_format_of item.to_sym
          values[:with_valid].each { |value| check_format_of item.to_sym, value }
          values[:with_invalid].each { |value| check_format_of item.to_sym, value, false }
        end unless item.is_a?(Hash) || item.is_a?(Array)
      end
    end

    # Tests that a set of attributes is required to fit within a certain list of acceptable values by the model. Best paired with validates_inclusion_of.
    # The default value will be used to test against the acceptable values. Additionally you can provide valid and invalid values to test
    # with by giving a hash that contains an array of values in the <em>:with_valid</em> and <em>:with_invalid</em> keys respectively.
    # A separate test will be run for each attribute given. The following example would result in three separate tests.
    # The first and last test only uses the default value to test with. The second test uses additional test values.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :style => "Contemporary"
    #     :direction => 'Vertical'
    #   }
    #
    #   test_inclusion_of :color, :style, {:with_valid => 'Classic', :with_invalid => ['Really Ugly', "Your parents' idea of cool"]}, :direction
    #
    # The following would accomplish the same thing
    #
    #   test_inclusion_of :color, :direction
    #   test_inclusion_of :style, :with_valid => 'Classic', :with_invalid => ['Really Ugly', "Your parents' idea of cool"]
    def test_inclusion_of(*args)
      args.each_with_index do |item, i|
        values = Hash.new { |hash, key| hash[key] = [] }
        i += 1
        while args[i].is_a?(Hash) || args[i].is_a?(Array)
          args[i] = {:with_valid => args[i]} if args[i].is_a?(Array)
          args[i].each do |key, test_values|
            test_values = [test_values] unless test_values.is_a?(Array)
            test_values.each { |value| values[key] << value }
          end
          i+= 1
        end
        
        define_method("test_inclusion_of_#{item.to_s}".to_sym) do
          check_inclusion_of item.to_sym
          values[:with_valid].each { |value| check_inclusion_of item.to_sym, value }
          values[:with_invalid].each { |value| check_inclusion_of item.to_sym, value, false }
        end unless item.is_a?(Hash) || item.is_a?(Array)
      end
    end

    # Tests that a set of attributes required to have a length within a specified range by the model. Best paired with validates_length_of.
    # Each attribute given can specify a range that limits the minimum and maximum lengths allowed.
    # If an exact size is required then a single value may be given or it can be not specified and the exact size can be inferred from the matching default attribute value 
    #
    # Two separate test will be run for each attribute given. One for a minimum length check and fone for a maximum length check.
    # The following example would result in eight separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :placement => "Ceiling"
    #   }
    #
    #   test_length_of :color, :location => 10, :name => 3..100, :placement => 4..17
    def test_length_of(*args)
      hash = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |x| hash[x] = nil }

      short, long = {}, {}
      hash.each do |item, val|
        val = [val].flatten unless val.is_a?(Range)
        short[item] = val.first
        long[item] = val.last
      end
      test_short(short)
      test_long(long)
    end

    # Tests that a set of attributes required to have a minimum length by the model. Best paired with validates_length_of.
    #
    # If a length is not given for an attribute, the minimum length will be inferred from the value used.
    # - If a value for an attribute is supplied then the inferred minimum length will be the length of the supplied value plus one.
    # - If a value for an attribute is not supplied then the inferred minimum length will be exactly the length of the default value for that attribute.
    #
    # If a length for an attribute is given without a value, the matching default attribute value will be trimmed down to a length of one less than the supplied length and then tested.
    #
    # A separate test will be run for each attribute given. The following example would result in four separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :placement => "Ceiling"
    #   }
    #
    #   test_short :name, :location => 4, :color => [2, "Re], :placement => [nil, "Floo"]
    def test_short(*args)
      hash = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |x| hash[x] = nil }
      hash.each do |item, length_and_value|
        minimum_length = [length_and_value].flatten[0]
        value_to_use = [length_and_value].flatten[1]
        define_method("test_short_#{item.to_s}".to_sym) { check_shorter_than item.to_sym, minimum_length, value_to_use }
      end
    end
  
    # Tests that a set of attributes required to have a maximum length by the model. Best paired with validates_length_of.
    #
    # If a length is not given for an attribute, the maximum length will be inferred from the value used.
    # - If a value for an attribute is supplied then the inferred maximum length will be the length of the supplied value minus one.
    # - If a value for an attribute is not supplied then the inferred maximum length will be exactly the length of the default value for that attribute.
    #
    # If a length for an attribute is given without a value, the matching default attribute value will be repeated until it reaches the length of one more than the supplied length and then tested.
    #
    # A separate test will be run for each attribute given. The following example would result in four separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue",
    #     :placement => "Ceiling"
    #   }
    #
    #   test_long :placement, :location => 10, :color => [7, "PurpleX"], :name => [nil, "Some really long name"]
    def test_long(*args)
      hash = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |x| hash[x] = nil }
      hash.each do |item, length_and_value|
        maximum_length = [length_and_value].flatten[0]
        value_to_use = [length_and_value].flatten[1]
        define_method("test_long_#{item.to_s}".to_sym) { check_longer_than item.to_sym, maximum_length, value_to_use }
      end
    end

    # Tests that a set of attributes is required to be unique by the model. Best paired with validates_uniqueness_of.
    # A separate test will be run for each attribute name given. The following example would result in three separate tests.
    #
    # Example:
    #
    #   DefaultValues =  {
    #     :name => "Some Name",
    #     :location => "123 Main",
    #     :color => "Blue"
    #   }
    #
    #   test_uniqueness_of :name, :location, :color
    def test_uniqueness_of(*args)
      args.each do |item|
        define_method("test_uniqueness_of_#{item.to_s}".to_sym) { check_uniqueness_of item.to_sym }
      end
    end
  end
  
  def self.included(base) #:nodoc:
    class << base
      include ClassMethods
#      include DelayedFixtures
    end
    base.method(:include).call(DelayedFixtures)
  end
  
  # Creates a new instance of the current model being tested, utilizing a hash of attribute names and values.
  #
  # If no values are passed the DefaultValues hash is used.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_with_default_values
  #     instance = new_instance
  #     assert_equal "Some Name", instance.name
  #     assert_equal "123 Main", instance.location
  #     assert_equal "Blue", instance.color
  #   end
  #
  #   def test_with_misspelled_values
  #     instance = new_instance(:name => "Sum Name", :location => "123 Mane", :color => "Bloo")
  #     assert_equal "Sum Name", instance.name
  #     assert_equal "123 Mane", instance.location
  #     assert_equal "Bloo", instance.color
  #   end
  #
  #   def test_with_only_name
  #     instance = new_instance(:name => "All Alone")
  #     assert_equal "All Alone", instance.name
  #     assert_nil instance.location
  #     assert_nil instance.color
  #   end
  def new_instance(values=nil)
    values = values.nil? ? default_values : resolve_delayed_fixtures(values)
    self.class.target.create(values)
  end
  
  # Creates a new instance of the current model being tested, utilizing the values hash being passed.
  # This instance is then passed to your block and destroyed when the block returns.
  #
  # If no values are passed the DefaultValues hash is used.
  #
  # The result of your block is returned.
  #
  # Example: (And a very contrived one at that. This example tests way to many unrelated things in one method)
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_two_separate_instances_and_name_collision
  #     
  #     reverse_color1 = with_instance do |default_instance|
  #       assert_equal "Some Name", default_instance.name
  #       assert_equal "123 Main", default_instance.location
  #       assert_equal "Blue", default_instance.color
  #       assert default_instance.valid?
  #       default_instance.color.reverse
  #     end
  #
  #     reverse_color2 = with_instance(default_values.merge(:color => "Red")) do |duplicate_name_instance|
  #       assert_equal "Some Name", duplicate_name_instance.name
  #       assert_equal "123 Main", duplicate_name_instance.location
  #       assert_equal "Red", duplicate_name_instance.color
  #       assert duplicate_name_instance.valid?
  #       duplicate_name_instance.color.reverse
  #     end
  #
  #     assert_equal "eulB", reverse_color1
  #     assert_equal "deR", reverse_color2
  #
  #     with_instance do |default_instance|
  #       assert default_instance.valid?
  #       with_instance(default_values.merge(:color => "Red")) do |duplicate_name_instance|
  #         assert !duplicate_name_instance.valid?
  #       end
  #     end
  #
  #   end
  def with_instance(values=nil, &block)
    instance = new_instance(values)
    begin
      yield(instance)
    ensure
      instance.destroy unless instance.nil? 
    end
  end
      
  # Creates a new instance of the current model from the DefaultValues hash but without the attributes specified.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_with_only_name
  #     instance = instance_without(:location, :color)
  #     assert_not_nil instance.name
  #     assert_nil instance.location
  #     assert_nil instance.color
  #   end
  def instance_without(*items)
    items = [items].flatten.map { |key| key.to_s.to_sym }
    values = default_values.reject{ |key, value| items.include?(key)}
    if block_given?
      with_instance values, &Proc.new
    else
      new_instance values
    end
  end
  
  # Creates a new instance of the current model from the DefaultValues hash merged with the hash of alternate values.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_with_badly_spelled_name_and_color
  #     instance = instance_with(:name => "Sum Name", :color => "Bloo")
  #     assert_equal "Sum Name", instance.name
  #     assert_equal "123 Main", instance.location
  #     assert_equal "Bloo", instance.color
  #   end
  def instance_with(hash)
    values = default_values.merge(hash)
    if block_given?
      with_instance values, &Proc.new
    else
      new_instance values
    end
  end
  
  # Asserts that an instance of the model can be created and saved using the default values.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_create
  #     check_create
  #   end
  def check_create
    with_instance do |instance|
      assert_not_nil instance, "Failed to create #{self.class.target.name}."
      assert instance.errors.empty?, "Failed to create valid #{self.class.target.name} with #{instance.inspect}.\n" + error_messages_from(instance).join("\n")
    end
  end
  
  # Asserts that an instance of the model can have the specified attributes updated and saved.
  # Then asserts that each updated value can be retrieved back from the database.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_update
  #     check_update :name => "Sum Name", :color => "Bloo"
  #   end
  def check_update(changed_values_hash)
    values = resolve_delayed_fixtures(changed_values_hash)
    id = values.delete(:id) { send(self.class.target.name.tableize.to_sym, :one).id }
    instance = self.class.target.find(id)
    instance.update_attributes(values)
    instance.save
    assert instance.errors.empty?, "Failed to update to a valid #{self.class.target.name} with #{values.inspect}.\n" + error_messages_from(instance).join("\n")
    instance.reload
    values.each do |attribute, new_value|
      current_value = instance.send(attribute)
      assert_equal current_value, new_value, "Failed to update #{attribute} to #{new_value} for #{self.class.target.name}.\nIt is currently #{current_value}."
    end
  end
  
  # Asserts that an attribute is required to be present by the model. Best paired with validates_presence_of.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_presence_of_name
  #     check_presence_of :name
  #   end
  def check_presence_of(item)
    instance_without(item) { |instance| assert instance.errors.invalid?(item), "#{self.class.target.name} should not have allowed an empty #{item}." }
  end
  
  # Asserts that an attribute is required to be numeric by the model. Best paired with validates_numericality_of.
  # If no value is given, a non numeric value will be created by treating the default value as a string,
  # removing the last digit, and adding the letter 'z' to the beginning of the string.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue",
  #     :quantity => 7
  #   }
  #
  #   def test_numericality_of_quantity
  #     check_numericality_of :quantity
  #     check_numericality_of :quantity, 'cabbadabbajabba'
  #   end
  def check_numericality_of(item, value=nil)
    value = ("z" + default_values[item].to_s)[0..-2] if value.nil?
    instance_with(item => value) { |instance| assert instance.errors.invalid?(item), "#{self.class.target.name} should not have allowed a nonnumeric #{item}." }
  end
  
  # Asserts that an attribute is required to fit a certain format by the model. Best paired with validates_format_of.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_format_of_location
  #     check_format_of :location
  #     check_format_of :location, "456 Elm St."
  #     check_format_of :location, "Street 101 WTF", false
  #   end
  def check_format_of(item, value=nil, valid=true)
    value = default_values[item].to_s if value.nil?
    instance_with(item => value) do |instance|
      errors = instance.errors.invalid?(item)
      if valid
        assert !errors, "#{self.class.target.name} should have allowed the format of #{value} for #{item}."
      else
        assert errors, "#{self.class.target.name} should not have allowed the format of #{value} for #{item}."
      end
    end
  end
  
  # Asserts that an attribute is required to fit within a certain list of acceptable values by the model. Best paired with validates_inclusion_of.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_inclusion_of_color
  #     check_inclusion_of :color
  #     check_inclusion_of :color, "Red"
  #     check_inclusion_of :color, "Blu", false
  #   end
  def check_inclusion_of(item, value=nil, valid=true)
    value = default_values[item].to_s if value.nil?
    instance_with(item => value) do |instance|
      errors = instance.errors.invalid?(item)
      if valid
        assert !errors, "#{self.class.target.name} should have allowed the inclusion of #{value} for #{item}."
      else
        assert errors, "#{self.class.target.name} should not have allowed the inclusion of #{value} for #{item}."
      end
    end
  end

  
  # Asserts that an attribute is required to have a minimum length by the model. Best paired with validates_length_of.
  #
  # If a length is not given, the minimum length will be inferred from the value used.
  # - If a value is supplied then the inferred minimum length will be the length of the supplied value plus one.
  # - If a value is not supplied then the inferred minimum length will be exactly the length of the default value for the attribute.
  #
  # If a length is given without a value, the default attribute value will be trimmed down to a length of one less than the supplied length and then tested.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_minimum_size_of_name
  #     # The following are equivalent if the model requires a minimum name length of 9.
  #     check_shorter_than :name
  #     check_shorter_than :name, 9
  #     check_shorter_than :name, nil, "Some Nam"
  #     check_shorter_than :name, 9, "ABC"
  #   end
  #
  #   def test_minimum_size_of_location
  #     # The following are equivalent if the model requires a minimum location length of 4.
  #     check_shorter_than :location, 4
  #     check_shorter_than :location, nil, "123"
  #     check_shorter_than :location, 4, "XYZ"
  #   end
  def check_shorter_than(item, length=nil, value=nil)
    length = (value.nil? ? default_values[item].to_s.length : (value.to_s.length + 1)) if length.nil?
    value = (" " + default_values[item].to_s)[1..length.to_i-1] if value.nil?
    instance_with(item => value) { |instance| assert instance.errors.invalid?(item), "#{self.class.target.name} should not have allowed #{item} shorter than #{length}." }
  end
  
  # Asserts that an attribute is required to have a maximum length by the model. Best paired with validates_length_of.
  #
  # If a length is not given, the maximum length will be inferred from the value used.
  # - If a value is supplied then the inferred maximum length will be the length of the supplied value minus one.
  # - If a value is not supplied then the inferred maximum length will be exactly the length of the default value for the attribute.
  #
  # If a length is given without a value, the default attribute value will be repeated until it reaches the length of one more than the supplied length and then tested.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_maximum_size_of_name
  #     # The following are equivalent if the model requires a maximum name length of 9.
  #     check_longer_than :name
  #     check_longer_than :name, 9
  #     check_longer_than :name, nil, "ABCDEFGHI"
  #     check_longer_than :name, 9, "Some really long name"
  #   end
  #
  #   def test_maximum_size_of_location
  #     # The following are equivalent if the model requires a maximum location length of 10.
  #     check_longer_than :location, 10
  #     check_longer_than :location, nil, "ABCDEFGHIJ"
  #     check_longer_than :location, 10, "12345678 ExtraLong Street"
  #   end
  def check_longer_than(item, length=nil, value=nil)
    length = (value.nil? ? default_values[item].to_s.length : (value.to_s.length - 1)) if length.nil?
    value = (default_values[item].to_s * length.to_i)[0..length.to_i] if value.nil?
    instance_with(item => value) { |instance| assert instance.errors.invalid?(item), "#{self.class.target.name} should not have allowed #{item} longer than #{length}." }
  end

  # Asserts that an attribute is required to be unique by the model. Best paired with validates_uniqueness_of.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #   }
  #
  #   def test_uniqueness_of_name
  #     check_uniqueness_of :name
  #   end
  def check_uniqueness_of(item)
    with_instance { |instance| assert self.class.target.create(default_values).errors.invalid?(item), "#{self.class.target.name} should not have allowed a duplicate #{item}." }
  end

  # Returns the default values hash after resolving any delayed fixtures.
  #
  # Example:
  #
  #   DefaultValues =  {
  #     :name => "Some Name",
  #     :location => "123 Main",
  #     :color => "Blue"
  #     :user_name => users(:test_user).name
  #   }
  #
  #   def test_delayed_fixture_resolution
  #     values = default_values
  #     assert_equal "Some Name", values.name
  #     assert_equal "123 Main", values.location
  #     assert_equal "Blue", values.color
  #     assert_equal User.find_by_name("test_user").name, values.user_name
  #   end
  def default_values
    resolve_delayed_fixtures self.class.default_values
  end

  # Recusively traverses an instance and returns a human readable set of errors that caused the instance not to validate.
  # The errors are nested so that if a child resource is causing the problem, it is easily identifiable.
  def error_messages_from(instance, indent=0)
    if instance.is_a?(ActiveRecord::Base)
      errors = Hash[*instance.errors.to_a.flatten]
      errors.map do |attr, msg|
        attr_human = (attr == "base") ? "" : "#{attr.humanize} "
        error_messages_from(instance.send(attr.to_sym), indent + 1).unshift("    " * indent + attr_human + msg)
      end
    else
      []
    end
  end

end
