#!/usr/bin/env bash

source ./parseCLI
parse_cli "$@"

# globals
version="FreeDNS $(cli color bold green 0.0.1) by https://github.com/stringmanolo"
verbose=false
debug=false

install_pkg_on_unknown_distro() {
  if [ -z "$1" ]; then
    return 1
  fi

  PKG_NAME="$1"
  declare -a MANAGERS=(
    "apt install -y"
    "yum install -y"
    "dnf install -y"
    "pacman -S --noconfirm"
    "zypper install -y"
    "apk add"
    "pkg install -y"
    "xbps-install -y"
  )

  for MANAGER_BASE in "${MANAGERS[@]}"; do
    for PREFIX in "sudo" ""; do
      INSTALL_CMD="$PREFIX $MANAGER_BASE $PKG_NAME"
      $INSTALL_CMD >/dev/null 2>&1

      if [ $? -eq 0 ]; then
        return 0
      fi
    done
  done

  return 1
}

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
-a, --address
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

accountCreate() {
  warning "Not implemented"
}

accountLogin() {
  # Get email
  email="[MISSING]"
  cli s e && email=${__CLI_S[e]}
  cli c email && email=${__CLI_C[email]}
  [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}$ ]] &&
    error "Email $(cli color bold red "$email") is not valid"

  # Get password
  password=""
  cli s p && password=${__CLI_S[p]}
  cli c password && password=${__CLI_C[password]}
  [[ ! $password =~ ^.{4,16}$ ]] && 
    error "Password $(cli color bold red "$password") is not valid.
  4 to 16 characters required and your password is $(cli color bold red "${#password}") characters long"

  
  [[ -f './freednsresponse.html' ]] &&  rm './freednsresponse.html';
  curl -X POST 'https://freedns.afraid.org/zc.php?step=2' \
  -d "username=$email" \
  -d "password=$password" \
  -d "remember=1" \
  -d "action=auth" \
  -c "./cookies.txt" \
  -o './freednsresponse.html' \
  -L --silent

  grep -q 'Logged in as ' './freednsresponse.html' ||  rm './cookies.txt' && error "Unable to login. Make sure your credentials are correct.
  Email: $(cli color bold cyan "$email") 
  Password: $(cli color bold cyan "$password")

  If everything is right check the file $(cli color bold cyan "./freednsresponse.html")";

  # Here user logged in sucessfully
  [[ -f './freednsresponse.html' ]] &&  rm './freednsresponse.html';
  
  exit "$(cli color bold bright_cyan AUTHENTICATED.) $(cli color cyan You are now logged in)"

}

accountStatus() {
  warning "Not implemented"
}

accountLogout() {
  warning "Not implemented"
}

accountEdit() {
  warning "Not implemented"
}

accountDelete() {
  warning "Not implemented"
}

domainCreate() {
  warning "Not implemented"
}

domainList() {
  warning "Not implemented"
}

domainEdit() {
  warning "Not implemented"
}

subdomainCreate() {
  warning "Not implemented"
  
  echo 'Getting captcha ...'
  curl 'https://freedns.afraid.org/securimage/securimage_show.php' \
  -b "./cookies.txt" \
  -c "./cookies.txt" \
  -o "./freednsCaptchaResponse.html" \
  -L --silent

  if ! install_pkg_on_unknown_distro chafa; then
    error "Unable to find package manager to install $(cli color bold cyan "chafa"), please do manually."
fi 

  chafa --size 80x30 './freednsCaptchaResponse.html'

  captchaCode="";
  read -r -p "Please, enter the captcha text and press enter: " captchaCode
  # TODO: OCR to bypass captcha auto.

  echo "Captcha is: $captchaCode"

  # TODO: Get id of domain from web list by searching user provided --domain
  # TODO: Options to show list of available domains and their ids
  domainID=29;
  subdomain=""
  address="1.2.3.4"
  record=""
  cli s s && subdomain=${__CLI_S[s]}
  cli c subdomain && subdomain=${__CLI_C[subdomain]} 

  cli s a && address=${__CLI_S[a]}
  cli c address && address=${__CLI_C[address]}

  cli s r && record=${__CLI_S[r]}
  cli c record && record=${__CLI_C[record]}

  curl -X POST "'https://freedns.afraid.org/subdomain/save.php?step=2" \
  -b "./cookies.txt" \
  -c "./cookies.txt" \
  -d "type=$record" \
  -d "subdomain=$subdomain" \
  -d "domain_id=$domainID" \
  -d "address=$address" \
  -d 'ttlalias=' \
  -d 'wildcard=0' \
  -d 'ref=L3N1YmRvbWFpby8=' \
  -d "captcha_code=$captchaCode" \
  -d 'send=Save!' \
  --silent -L -o freedns_subdomain_creation_response.html

  # TODO: Check if subdomain was created sucessfully by checking /domains web and grep the domain from the html
  warning "Subdomain creation check not implemented"

}

subdomainList() {
  warning "Not implemented"
}

subdomainEdit() {
  warning "Not implemented"
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



