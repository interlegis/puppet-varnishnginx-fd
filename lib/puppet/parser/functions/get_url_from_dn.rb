# Funcao para, a partir de uma string de Distinguished Name, 
# gerar uma string de URL.
# 
# Parametros:
#   stringdn - A string contendo o Dinstinguished Name
#   baseurl  - Booleano que indica se a URL retornada inclui
#              apenas a URL base ou a URL completa. 
#              Padrao: true (URL base apenas).
# 
# Autor: Fabio Rauber
# Email: fabiorauber@gmail.com
# Data:  25/09/2014

require 'net/ldap/dn'

module Puppet::Parser::Functions
  newfunction(:get_url_from_dn, :type => :rvalue) do |args|
    stringdn = args[0]
    baseurl = true
    baseurl = args[1] unless (args[1] != true and args[1] != false)

    dn = Net::LDAP::DN.new(stringdn)
    url = ''
    dn.each_pair do |key, value|
      if baseurl == true 
        if key == 'dc' 
          url << "#{value}."
        end
      else
        if key == 'cn' or key == 'dc'
          url << "#{value}."
        end
      end
    end 
    return url.chop! if url.end_with? '.'
  end
end
