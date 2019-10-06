require "json-schema"

module ClientApi

  def validate(res, *options)
    options.map do |data|
      raise_error('key (or) operator is not given!') if data[:key].nil? && data[:operator].nil?
      raise_error('value (or) type is not given!') if data[:value].nil? && data[:type].nil?

      @resp = res
      key = data[:key].split("->")

      key.map do |method|
        method = method.to_i if is_num?(method)
        @resp = @resp.send(:[], method)
      end

      value ||= data[:value]
      operator = data[:operator]
      type = data[:type] if data[:type] || data[:type] != {} || !data[:type].empty?

      case operator
      when '=', '==', 'eql?', 'equal', 'equal?'
        # value validation
        expect(value).to eq(@resp) if value != nil

        # datatype validation
        if (type == "boolean" || type == "bool") && value.nil?
          expect(%w[TrueClass, FalseClass].any? {|bool| @resp.class.to_s.include? bool}).to be true
        else
          expect(datatype(type, value)).to eq(@resp.class)
        end

      when '!', '!=', '!eql?', 'not equal', '!equal?'
        # value validation
        expect(value).not_to eq(@resp) if value != nil

        # datatype validation
        if (type == "boolean" || type == "bool") && value.nil?
          expect(%w[TrueClass, FalseClass].any? {|bool| @resp.class.to_s.include? bool}).not_to be true
        else
          expect(datatype(type, value)).not_to eq(@resp.class)
        end
      else
        raise_error('operator not matching')
      end
    end
  end

  def validate_schema(param1, param2)
    expected_schema = JSON::Validator.validate(param1, param2)
    expect(expected_schema).to be true
  end

  def datatype(type, value)
    if (type.downcase == 'string') || (type.downcase.== 'str')
      String
    elsif (type.downcase.== 'integer') || (type.downcase.== 'int')
      Integer
    elsif (type.downcase == 'symbol') || (type.downcase == 'sym')
      Symbol
    elsif (type.downcase == 'array') || (type.downcase == 'arr')
      Array
    elsif (type.downcase == 'object') || (type.downcase == 'obj')
      Object
    elsif (type.downcase == 'boolean') || (type.downcase == 'bool')
      value === true ? TrueClass : FalseClass
    elsif type.downcase == 'float'
      Float
    elsif type.downcase == 'hash'
      Hash
    elsif type.downcase == 'complex'
      Complex
    elsif type.downcase == 'rational'
      Rational
    elsif type.downcase == 'fixnum'
      Fixnum
    elsif type.downcase == 'falseclass'
      FalseClass
    elsif type.downcase == 'trueclass'
      TrueClass
    elsif type.downcase == 'bignum'
      Bignum
    else
    end
  end

  def is_num?(str)
    if Float(str)
      true
    end
  rescue ArgumentError, TypeError
    false
  end

  def validate_json(actual, expected)
    param1 = JSON.parse(actual.to_json)
    param2 = JSON.parse(expected.to_json)

    @actual_key, @actual_value = [], []
    deep_traverse(param2) do |path, value|
      if !value.is_a?(Hash)
        key_path = path.map! {|k| k}
        @actual_key << key_path.join("->").to_s
        @actual_value << value
      end
    end

    Hash[@actual_key.zip(@actual_value)].map do |data|
      @resp = param1
      key = data[0].split("->")

      key.map do |method|
        method = method.to_i if is_num?(method)
        @resp = @resp.send(:[], method)
      end

      value = data[1]
      @assert, @final_assert, @overall = [], [], []

      if !value.is_a?(Array)
        expect(value).to eq(@resp)
      else
        @resp.each_with_index do |resp, i|
          value.to_a.each_with_index do |val1, j|
            val1.to_a.each_with_index do |val2, k|
              if resp.to_a.include? val2
                @assert << true
              else
                @assert << false
              end
            end
            @final_assert << @assert
            @assert = []

            if @resp.count == @final_assert.count
              @final_assert.each_with_index do |result, i|
                if result.count(true) == val1.count
                  @overall << true
                  break
                elsif @final_assert.count == i+1
                  expect(value).to eq(@resp)
                end
              end
              @final_assert = []
            end

          end
        end

        if @overall.count(true) == value.count
          return
        else
          expect(value).to eq(@resp)
        end

      end
    end
  end

  def deep_traverse(hash, &block)
    stack = hash.map {|k, v| [[k], v]}

    while not stack.empty?
      key, value = stack.pop
      yield(key, value)
      if value.is_a? Hash
        value.each do |k, v|
          if v.is_a?(String) then
            if v.empty? then
              v = nil
            end
          end
          stack.push [key.dup << k, v]
        end
      end
    end
  end

end