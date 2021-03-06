module DNSimple
  class Record
    include HTTParty

    attr_accessor :id

    attr_accessor :domain

    attr_accessor :name

    attr_accessor :content

    attr_accessor :record_type

    attr_accessor :ttl

    attr_accessor :prio

    #:nodoc:
    def initialize(attributes)
      attributes.each do |key, value|
        m = "#{key}=".to_sym
        self.send(m, value) if self.respond_to?(m)
      end
    end

    def fqdn
      [name, domain.name].delete_if { |v| v !~ DNSimple::BLANK_REGEX }.join(".")
    end

    def save(options={})
      record_hash = {}
      %w(name content ttl prio).each do |attribute|
        record_hash[DNSimple::Record.resolve(attribute)] = self.send(attribute)
      end

      options.merge!(DNSimple::Client.standard_options_with_credentials)
      options.merge!(:body => {:record => record_hash})

      response = self.class.put("#{DNSimple::Client.base_uri}/domains/#{domain.id}/records/#{id}.json", options)

      pp response if DNSimple::Client.debug?

      case response.code
      when 200
        return self
      when 401
        raise DNSimple::AuthenticationFailed
      else
        raise DNSimple::Error, "Failed to update record: #{response.inspect}" 
      end
    end
    
    def delete(options={})
      options.merge!(DNSimple::Client.standard_options_with_credentials)
      self.class.delete("#{DNSimple::Client.base_uri}/domains/#{domain.id}/records/#{id}", options)
    end
    alias :destroy :delete

    def self.resolve(name)
      aliases = {
        'priority' => 'prio',
        'time-to-live' => 'ttl'
      }
      aliases[name] || name
    end

    def self.create(domain, name, record_type, content, options={})
      record_hash = {:name => name, :record_type => record_type, :content => content}
      record_hash[:ttl] = options.delete(:ttl) || 3600
      record_hash[:prio] = options.delete(:priority)
      record_hash[:prio] = options.delete(:prio) || ''
      
      options.merge!(DNSimple::Client.standard_options_with_credentials)
      options.merge!({:body => {:record => record_hash}})

      response = self.post("#{DNSimple::Client.base_uri}/domains/#{domain.name}/records", options) 

      pp response if DNSimple::Client.debug?

      case response.code
      when 201
        return DNSimple::Record.new({:domain => domain}.merge(response["record"]))
      when 401
        raise DNSimple::AuthenticationFailed
      when 406
        raise DNSimple::RecordExists.new("#{name}.#{domain.name}", response["errors"])
      else
        raise DNSimple::Error, "Failed to create #{name}.#{domain.name}: #{response["errors"]}"
      end
    end

    def self.find(domain, id, options={})
      options.merge!(DNSimple::Client.standard_options_with_credentials)
      response = self.get("#{DNSimple::Client.base_uri}/domains/#{domain.name}/records/#{id}", options)

      pp response if DNSimple::Client.debug?

      case response.code
      when 200
        return DNSimple::Record.new({:domain => domain}.merge(response["record"]))
      when 401
        raise DNSimple::AuthenticationFailed
      when 404
        raise DNSimple::RecordNotFound, "Could not find record #{id} for domain #{domain.name}"
      else
        raise DNSimple::Error, "Failed to find domain #{domain.name}/#{id}: #{response["errors"]}"
      end
    end

    def self.all(domain, options={})
      options.merge!(DNSimple::Client.standard_options_with_credentials)
      response = self.get("#{DNSimple::Client.base_uri}/domains/#{domain.name}/records", options)

      pp response if DNSimple::Client.debug?

      case response.code
      when 200
        response.map { |r| DNSimple::Record.new({:domain => domain}.merge(r["record"])) }
      when 401
        raise DNSimple::AuthenticationFailed, "Authentication failed"
      else
        raise DNSimple::Error, "Error listing domains: #{response.code}"
      end
    end

  end
end
