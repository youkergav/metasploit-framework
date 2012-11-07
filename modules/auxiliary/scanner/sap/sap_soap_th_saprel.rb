##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##

##
# This module is based on, inspired by, or is a port of a plugin available in 
# the Onapsis Bizploit Opensource ERP Penetration Testing framework - 
# http://www.onapsis.com/research-free-solutions.php.
# Mariano Nuñez (the author of the Bizploit framework) helped me in my efforts
# in producing the Metasploit modules and was happy to share his knowledge and
# experience - a very cool guy. I'd also like to thank Chris John Riley, 
# Ian de Villiers and Joris van de Vis who have Beta tested the modules and 
# provided excellent feedback. Some people just seem to enjoy hacking SAP :)
##

require "msf/core"

class Metasploit4 < Msf::Auxiliary

	include Msf::Exploit::Remote::HttpClient
	include Msf::Auxiliary::Report
	include Msf::Auxiliary::Scanner

	def initialize
		super(
			'Name' => 'SAP RFC TH_SAPREL',
			'Version' => '$Revision$',
			'Description' => %q{ This module makes use of the TH_SAPREL RFC (via SOAP) to return the SAP software, OS and DB versions.}, 
			'References' => [[ 'URL', 'http://labs.mwrinfosecurity.com' ]],
			'Author' => [ 'Agnivesh Sathasivam','nmonkee' ],
			'License' => BSD_LICENSE
			)
		register_options(
			[
				OptString.new('CLIENT', [true, 'Client', nil]),
				OptString.new('USERNAME', [true, 'Username', nil]),
				OptString.new('PASSWORD', [true, 'Password', nil]),
			], self.class)
	end
	
	def run_host(ip)
		data = '<?xml version="1.0" encoding="utf-8" ?>'
		data << '<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
		data << '<env:Body>'
		data << '<n1:TH_SAPREL xmlns:n1="urn:sap-com:document:sap:rfc:functions" env:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
		data << '</n1:TH_SAPREL>'
		data << '</env:Body>'
		data << '</env:Envelope>'
		user_pass = Rex::Text.encode_base64(datastore['USERNAME'] + ":" + datastore['PASSWORD'])
		print_status("[SAP] #{ip}:#{rport} - sending SOAP TH_SAPREL request")
		begin
			res = send_request_raw({
				'uri' => '/sap/bc/soap/rfc?sap-client=' + datastore['CLIENT'] + '&sap-language=EN',
				'method' => 'POST',
				'data' => data,
				'headers'  =>{
					'Content-Length' => data.size.to_s,
					'SOAPAction' => 'urn:sap-com:document:sap:rfc:functions',
					'Cookie' => 'sap-usercontext=sap-language=EN&sap-client=' + datastore['CLIENT'],
					'Authorization' => 'Basic ' + user_pass,
					'Content-Type' => 'text/xml; charset=UTF-8',
					}
				}, 45)
			if res and res.code == 500
				response = res.body
				#error.push(response.scan(%r{<faultstring>(.*?)</faultstring>}))
				error.push(response.scan(%r{<message>(.*?)</message>}))
				success = false
			elsif res and res.code == 200
				kern_comp_on = $1 if res.body =~ /<KERN_COMP_ON>(.*)<\/KERN_COMP_ON>/i
				kern_comp_time = $1 if res.body =~ /<KERN_COMP_TIME>(.*)<\/KERN_COMP_TIME>/i
				kern_dblib = $1 if res.body =~ /<KERN_DBLIB>(.*)<\/KERN_DBLIB>/i
				kern_patchlevel = $1 if res.body =~ /<KERN_PATCHLEVEL>(.*)<\/KERN_PATCHLEVEL>/i
				kern_rel =  $1 if res.body =~ /<KERN_REL>(.*)<\/KERN_REL>/i
				saptbl = Msf::Ui::Console::Table.new(
					Msf::Ui::Console::Table::Style::Default,
					'Header' => "[SAP] System Info",
					'Prefix' => "\n",
					'Postfix' => "\n",
					'Indent' => 1,
					'Columns' =>
						[
							"Info",
							"Value"
						])
				saptbl << [ "OS Kernel version", kern_comp_on ]
				saptbl << [ "SAP compile time", kern_comp_time ]
				saptbl << [ "DB version", kern_dblib ]
				saptbl << [ "SAP patch level", kern_patchlevel ]
				saptbl << [ "SAP Version", kern_rel ]
				print(saptbl.to_s)
			else
				print_error("[SAP] #{ip}:#{rport} - error message: " + res.code.to_s + " " + res.message)
			end
		rescue ::Rex::ConnectionError
			print_error("#[SAP] #{ip}:#{rport} - Unable to connect")
			return
		end
		if success == false
			err = error.join().chomp
			print_error("#[SAP] #{ip}:#{rport} - #{err.gsub('&#39;','\'')}")
		end
	end
end
