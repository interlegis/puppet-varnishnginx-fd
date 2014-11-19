#init.pp

class varnishnginxfd ( $ipHostNumber = '',
                      ){
  
  $vhosts = hiera_hash("(objectClass=varnishNginxVhost)")
  create_resources("varnishnginxfd::vhost", $vhosts)
   
}
