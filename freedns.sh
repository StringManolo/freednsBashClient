#!/usr/bin/env bash

source ./parseCLI
parse_cli "$@"

# globals
version="FreeDNS $(cli color bold green 0.0.1) by https://github.com/stringmanolo"
verbose=false
debug=false



exit() {
  local msg="$1"
  echo -e "$msg"
  builtin exit 0
}

info() {
  echo "$(cli color cyan [INFO]) $1"
}

success() {
  echo "$(cli color green [SUCCESS]) $1"
}

error() {
  echo "$(cli color bold red [ERROR]) $1"
  builtin exit
}

warning() {
  echo "$(cli color yellow [WARNING]) $1"
}


showUsage() {
cat << SHOWUSAGE
$(cli color bold red USAGE)
./freedns.sh [$(cli color bold green "command")] [$(cli color bold cyan subcommand)] [options]

$(cli color bold red COMMANDS)
  $(cli color bold green account)
    $(cli color bold cyan create)
    $(cli color bold cyan login)
    $(cli color bold cyan status)
    $(cli color bold cyan logout)
    $(cli color bold cyan edit)
    $(cli color bold cyan delete)

  $(cli color bold green domain)
    $(cli color bold cyan create)
    $(cli color bold cyan list)
    $(cli color bold cyan edit)

  $(cli color bold green subdomain)
    $(cli color bold cyan create)
    $(cli color bold cyan list)
    $(cli color bold cyan edit)

$(cli color bold red OPTIONS)
-e, --email      
-p, --password   
-d, --domain     
-s, --subdomain
-r, --record A AAAA CNAME CAA NS MX TXT SPF LOC HINFO RP SVR SSHFP
    --destination
-c, --captcha
    
-v, --verbose
-d, --debug

--version

$(cli color bold red EXAMPLES)
freedns $(cli color bold green account) $(cli color bold cyan login) -e stringmanolo@gmail.com -p myPassword -vd

SHOWUSAGE

builtin exit
}





cmd=$(cli o | sed -n '1p')
subcmd=$(cli o | sed -n '2p')
subsubcmd=$(cli o | sed -n '3p')

if      cli noArgs              ;then    showUsage                 ;fi
if cli s h || cli c help        ;then    showUsage                 ;fi
if cli s v || cli c verbose     ;then    verbose=true              ;fi
if cli s d || cli c debug       ;then    debug=true                ;fi 
if            cli c version     ;then    exit "$version"           ;fi

if [[ $cmd =~ ^account$  ]]     ;then
  if [[ $subcmd =~ ^create$ ]]  ;then    accountCreate             ;elif 
     [[ $subcmd =~ ^login$  ]]  ;then    accountLogin              ;elif
     [[ $subcmd =~ ^status$ ]]  ;then    accountStatus             ;elif
     [[ $subcmd =~ ^logout$ ]]  ;then    accountLogout             ;elif
     [[ $subcmd =~ ^edit$   ]]  ;then    accountEdit               ;elif
     [[ $subcmd =~ ^delete$ ]]  ;then    accountDelete             ;else
     [[    -z $subcmd       ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green account)" ;
  fi 

elif [[ $cmd =~ ^domain$    ]]  ;then  
  if [[ $subcmd =~ ^create$ ]]  ;then    domainCreate              ;elif
     [[ $subcmd =~ ^list$   ]]  ;then    domainList                ;elif
     [[ $subcmd =~ ^edit$   ]]  ;then    domainEdit                ;else
     [[    -z $subcmd       ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green domain)" ;
  fi

elif [[ $cmd =~ ^subdomain$ ]]  ;then
  if [[ $subcmd =~ ^create$ ]]  ;then    subdomainCreate           ;elif
     [[ $subcmd =~ ^list$   ]]  ;then    subdomainList             ;elif
     [[ $subcmd =~ ^edit$   ]]  ;then    subdomainEdit             ;else
     [[    -z $subcmd       ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green subdomain)" ;
  fi

elif [[ $cmd =~ ^help$      ]]  ;then    showUsage 


else
  error "The command $(cli color bold red $cmd) is not a valid command"
fi



