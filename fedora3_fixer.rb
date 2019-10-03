require 'csv'
require 'rexml/document'
require 'rexml/xpath'

class Fedora3Fixer
  def self.xmldir
    "/tmp/objects/"
  end

  def self.check_http_error(response)
    error = false
    if (!response)
      error = "No response to POST"
    end
    if (response && response.code[0] != "2")
      error = "Unexpected response: #{response.code} #{response.message} #{response.body}"
    end
    if (error)
      raise error
    end
  end

  def self.do_http(resource, req, uri, body, mime)
    req.basic_auth resource.api_username, resource.api_password
    req.body = body
    if (mime)
      req.add_field('Content-Type', mime)
    end
    response = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req)}
    self.check_http_error response
    response
  end

  def self.purge_relationship(resource, subject, predicate, object, is_literal, datatype)
    uri = URI("#{resource.api_base}/objects/#{resource.pid}/relationships")
    params = {
      subject: subject,
      predicate: predicate,
      object: object,
      isLiteral: is_literal,
      datatype: datatype
    }
    uri.query = URI.encode_www_form(params.compact)
    req = Net::HTTP::Delete.new(uri)
    self.do_http(resource, req, uri, nil, nil)
  end

  def self.fix_parent(pid, parent_pid)
    resource = Fedora3Object.from_pid(pid)
    self.purge_relationship(
      resource,
      "info:fedora/#{pid}",
      'info:fedora/fedora-system:def/relations-external#isMemberOf',
      "info:fedora/",
      'false',
      nil
    )
    resource.add_relationship(
      "info:fedora/#{pid}",
      'info:fedora/fedora-system:def/relations-external#isMemberOf',
      "info:fedora/#{parent_pid}",
      'false',
      nil
    )
  end

  def self.regenerate_with_title(pid, title)
    resource = Fedora3Object.from_pid(pid)
    resource.title = title
    resource.core_ingest("A")
    resource.collection_ingest
    resource.resource_collection_ingest
  end

  def self.restore_titles_from_csv(file)
    CSV.foreach(file) do |row|
      puts "PID: #{row[0]}, Title: #{row[1]}"
      self.regenerate_with_title(row[0], row[1])
    end
  end

  def self.restore_parents_from_csv(file)
    CSV.foreach(file) do |row|
      puts "PID: #{row[0]}, Parent PID: #{row[1]}"
      self.fix_parent(row[0], row[1])
    end
  end

  def self.add_datastream_from_string(resource, contents, stream, mime_type)
    resource.add_datastream(
      stream,
      'M',
      nil,
      nil,
      "#{resource.pid.tr(':', '_')}_#{stream}",
      'false',
      'A',
      nil,
      'MD5',
      nil,
      mime_type,
      "Initial Ingest addDatastream - #{stream}",
      contents
    )
  end

  def self.restore_thumbs_from_csv(file)
    CSV.foreach(file) do |row|
      puts "Main PID: #{row[0]}, Thumb PID: #{row[1]}"
      self.restore_thumbnail(row[0], row[1])
    end
  end

  def self.restore_thumbnail(target_pid, thumb_pid)
    source = Fedora3Object.from_pid(thumb_pid)
    thumb = source.datastream_dissemination('THUMBNAIL')
    self.add_datastream_from_string(Fedora3Object.from_pid(target_pid), thumb, 'THUMBNAIL', 'image/jpeg')
  end

  def self.restore_datastream(resource, stream, label, xml)
    if (!xml)
      puts "WARNING: Datastream #{stream} missing..."
      return
    end
    puts "Restoring #{stream}..."
    begin
      resource.add_datastream(
        stream,
        'X',
        nil,
        nil,
        label,
        'false',
        'A',
        nil,
        'DISABLED',
        nil,
        'text/xml',
        'Restore ' + stream + ' stream from backup',
        xml.to_s
      )
    rescue RuntimeError
      puts "Problem writing XML: #{xml.to_s}"
      raise
    end
  end

  def self.restore_from_xml(pid)
    xmlfile = self.xmldir + pid.sub(':', '_') + '.xml'
    xml = REXML::Document.new(File.new(xmlfile))
    license = REXML::XPath.first(
      xml,
      "//foxml:datastream[@ID='LICENSE']/foxml:datastreamVersion/foxml:xmlContent/METS:rightsMD",
      {"foxml" => "info:fedora/fedora-system:def/foxml#", "METS" => "http://www.loc.gov/METS/"}
    )
    processmd = REXML::XPath.first(
      xml,
      "//foxml:datastream[@ID='PROCESS-MD']/foxml:datastreamVersion/foxml:xmlContent/DIGIPROVMD:DIGIPROVMD",
      {"foxml" => "info:fedora/fedora-system:def/foxml#", "DIGIPROVMD" => "http://www.loc.gov/PMD"}
    )
    agents = REXML::XPath.first(
      xml,
      "//foxml:datastream[@ID='AGENTS']/foxml:datastreamVersion/foxml:xmlContent/METS:metsHdr",
      {"foxml" => "info:fedora/fedora-system:def/foxml#", "METS" => "http://www.loc.gov/METS/"}
    )
    xmldates = REXML::XPath.match(
      xml,
      "//foxml:datastream[@ID='DC']/foxml:datastreamVersion/@CREATED",
      {"foxml" => "info:fedora/fedora-system:def/foxml#"}
    )
    sorted_dates = xmldates.sort { |a,b| DateTime.iso8601(a.to_s) <=> DateTime.iso8601(b.to_s) }
    maxdate = sorted_dates.last.to_s
    dc = REXML::XPath.first(
      xml,
      "//foxml:datastream[@ID='DC']/foxml:datastreamVersion[@CREATED='" + maxdate + "']/foxml:xmlContent/oai_dc:dc",
      {"foxml" => "info:fedora/fedora-system:def/foxml#", "oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/"}
    )
    sequence = REXML::XPath.first(
      xml,
      "//foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion/foxml:xmlContent/rdf:RDF/rdf:Description/vudl:sequence/text()",
      {"foxml" => "info:fedora/fedora-system:def/foxml#", "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "vudl" => "http://vudl.org/relationships#"}
    )
    resource = Fedora3Object.from_pid pid
    self.restore_datastream(resource, 'LICENSE', 'License for this Resource', license)
    self.restore_datastream(resource, 'AGENTS', 'AGENTS for this Resource', agents)
    self.restore_datastream(resource, 'PROCESS-MD', 'Process Metadata for this Resource', processmd)
    puts "Modifying DC..."
    resource.modify_datastream(
      'DC',
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      'text/xml',
      'Restore DC stream from backup',
      nil,
      nil,
      dc.to_s
    )
    if sequence
      puts "Restoring sequence number..."
      resource.add_relationship(
        "info:fedora/#{pid}",
        'http://vudl.org/relationships#sequence',
        sequence,
        'false',
        nil
      )
    end
  end

  def self.restore_processmd_from_file(pid)
    xmlfile = '/tmp/process-md/' + pid.sub(':', '_') + '.xml'
    processmd = File.open(xmlfile, 'rb').read
    resource = Fedora3Object.from_pid pid
    self.restore_datastream(resource, 'PROCESS-MD', 'Process Metadata for this Resource', processmd)
  end

  def self.restore_processmd_from_pid_list(file)
    CSV.foreach(file) do |row|
      puts "Restoring PID: #{row[0]}"
      self.restore_processmd_from_file(row[0])
    end
  end

  def self.restore_xml_from_pid_list(file)
    CSV.foreach(file) do |row|
      puts "Restoring PID: #{row[0]}"
      self.restore_from_xml(row[0])
    end
  end
end

