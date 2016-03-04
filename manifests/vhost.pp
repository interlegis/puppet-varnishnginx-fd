#vhost.pp

define varnishnginxfd::vhost ( $dn,
                               $cn,
                               $backendpath     = '/', 
                               $backends        = [], 
                               $vhostmonster    = false, 
                               $objectclass     = [],
                               $ssl             = false,
                               $specialprobeurl = '/',
                             ) {

  $baseurl = get_url_from_dn($dn[0],true)
  $nome = $cn[0]
  $url = "${nome}.${baseurl}"

  varnish::probe { "health_$nome":
    window => '8',
    timeout => '5s',
    threshold => '3',
    interval => '5s',
    request => [ "GET ${specialprobeurl} HTTP/1.1",
                 "Host: ${url}",
                 "Connection: close" ],
  }

  # Create Backends
  varnishnginxfd::int_backends { $backends:
    probe => "health_$nome",
  }

  # Create director
  $servers_n = regsubst($backends,'[^A-Za-z0-9_]','_','G')
  $servers_name = prefix($servers_n,'ip_')

  varnish::director { "director_$nome":
    type => 'round-robin',
    backends => $servers_name,
    require => Varnishnginxfd::Int_backends[$backends],
  }

  if ( $ssl[0] == "TRUE" ) {
    ## O site usa SSL
    certificates::certificate { $nome:
      source => "puppet:///files/certificates/$nome.crt",
    }
    certificates::key { $nome:
      source => "puppet:///files/certificates/$nome.key",
    }

    nginx::resource::vhost { $url:
      proxy        => 'http://localhost:80',
      ssl          => true,
      listen_port  => 443,
      ssl_port     => 443,
      ssl_cert     => "/etc/ssl/certs/$nome.crt",
      ssl_key      => "/etc/ssl/private/$nome.key",
      ssl_stapling => true,
    }

    varnish::selector { "redirectssl_$nome":
      condition => "req.http.host ~ \"$url\" && req.http.X-Forwarded-Proto !~ \"(?i)https\"",
      movedto => "https://$url",
    }

    if ( $vhostmonster[0] == "TRUE") {
      varnish::selector { "director_$nome":
        condition => "req.http.host ~ \"$url\" && req.http.X-Forwarded-Proto ~ \"(?i)https\"",
        newurl => "\"/VirtualHostBase/https/\" + req.http.host + \":443/$backendpath/VirtualHostRoot\" + req.url",
      }
    } else {
      varnish::selector { "director_$nome":
        condition => "req.http.host ~ \"$url\" && req.http.X-Forwarded-Proto ~ \"(?i)https\"",
      }
    }  

  } else {
    ## O site não usa SSL
    if ( $vhostmonster[0] == "TRUE" ) {
      varnish::selector { "director_$nome":
        condition => "req.http.host ~ \"$url\"",
        newurl => "\"/VirtualHostBase/http/\" + req.http.host + \":80/$backendpath/VirtualHostRoot\" + req.url",
      }
    } else {
      varnish::selector { "director_$nome":
        condition => "req.http.host ~ \"$url\"",
      }

      if ( inline_template('<%= url.split(".")[0] %>') == 'www' ) {
        $urlsemwww = inline_template('<%= url.partition(".")[2] %>')
        varnish::selector { "redirect_$nome":
          condition => "req.http.host ~ \"$urlsemwww\"",
          movedto => "http://$url",
        }
      }
    }
  }

}

# Internal helper define to create the backends
define varnishnginxfd::int_backends ( $probe ) {
  $server_n = regsubst($title,'[^A-Za-z0-9_]','_','G')
  $server_name = "ip_$server_n"

  $portstr = inline_template('<%= title.split(":")[1] %>')
  $host = inline_template('<%= title.split(":")[0] %>')

  if ( $portstr != '' ) {
    $port = $portstr
  } else {
    $port = '80'
  }

  varnish::backend { $server_name:
    host => $host,
    port => $port,
    probe => $probe,
  }
}


