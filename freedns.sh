#!/usr/bin/env bash

source ./parseCLI
parse_cli "$@"

# globals
version="FreeDNS $(cli color bold green 0.0.1) by https://github.com/stringmanolo"
verbose=false
debug=false

# This is for install dependencies like CHAFA to view captchas in terminal, etc.
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

# Ouput utils
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

# Printing when using ./freedns.sh help ./freedns.sh ./freedns.sh --help, etc.
showUsage() {
cat << SHOWUSAGE
$(cli color bold red USAGE)
./freedns.sh [$(cli color bold green "command")] [$(cli color bold cyan subcommand)] [options]

$(cli color bold red COMMANDS)
  $(cli color bold green account)
    $(cli color bold cyan create) --email --password --firstname --lastname --username 
    $(cli color bold cyan login) --email --password 
    $(cli color bold cyan status)
    $(cli color bold cyan logout)
    $(cli color bold cyan edit)
    $(cli color bold cyan delete)

  $(cli color bold green domain)
    $(cli color bold cyan create)
    $(cli color bold cyan list)
    $(cli color bold cyan edit)
    $(cli color bold cyan delete)

  $(cli color bold green subdomain)
    $(cli color bold cyan available)
    $(cli color bold cyan create) --domain --subdomain ( --record --address ) 
    $(cli color bold cyan list)
    $(cli color bold cyan edit)
    $(cli color bold cyan delete)

$(cli color bold red OPTIONS)
-a, --address
-e, --email      
-p, --password   
    --domain     
-s, --subdomain
-r, --record A AAAA CNAME CAA NS MX TXT SPF LOC HINFO RP SVR SSHFP
    --record-value  
    --destination
    --firstname
    --lastname
    --username

-v, --verbose
-d, --debug

--version

$(cli color bold red EXAMPLES)
./freedns.sh $(cli color bold green account) $(cli color bold cyan create) --firstname Manolo --lastname String --username stringmanolo --email stringmanolo@gmail.com --password myPassword123
./freedns.sh $(cli color bold green account) $(cli color bold cyan login) -e stringmanolo@gmail.com -p myPassword123 
./freedns.sh $(cli color bold green subdomain) $(cli color bold cyan available)
./freedns.sh $(cli color bold green subdomain) $(cli color bold cyan create) --domain mooo.com --subdomain stringmanolo  

SHOWUSAGE

builtin exit
}

# The HTTP Request to subdomain creation needs an ID for the domain. 
getSubdomainID() {
  local CONFIG_FILE="./subdomainList.config"
  local domain="$1"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Error: Config file $(cli color bold yellow "$CONFIG_FILE") not found"
  fi
  
  local result=$(grep -i "^$domain " "$CONFIG_FILE" | head -1)

  if [[ -z "$result" ]]; then
    error "subdomain $(cli color bold yellow "$domain") not found in $(cli color bold yellow "$CONFIG_FILE")"
  fi
  
  echo "$result" | awk '{print $2}'
}

# THIS DOES NOT WORK, NEED SOME TWEAKS TO MAKE IT WORK. BUT I DON'T NEED AUTOMATION ANYWAYS. NOT WORTH THE TIME INVESTMENT.
# KEEPING IT HERE IN CASE I WAMT TO PLAY AROUND WITH IT.
# Try to resolve captcha without user interaction using Gemini 2.5-flash model.
resolveCaptcha() {
  IMAGE_PATH="$1"

  if [ -z "$IMAGE_PATH" ]; then
    error "resolveCaptcha could not find the image"
    return 1
  fi

  if [ -z "$GEMINI_API_KEY" ]; then
    warning "Define your key: export GEMINI_API_KEY='YourKeyHere'"
    error "GEMINI_API_KEY environment variable is not defined."
  fi

  if [ ! -f "$IMAGE_PATH" ]; then
    error "Image file not found at: $IMAGE_PATH"
  fi

  B64_IMAGE=$(cat "$IMAGE_PATH" | base64 | tr -d '\n')
  MIME_TYPE="image/png"

  INSTRUCTION="You are a dedicated and highly accurate OCR specialist. Your sole task is to read the characters displayed in the provided image, which is a CAPTCHA. Provide only the extracted text and nothing else, without any explanation, markdown, or commentary."
  OCR_PROMPT="Extract the text characters from this image."
  FINAL_PROMPT="$INSTRUCTION $OCR_PROMPT"

  RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
    -H 'Content-Type: application/json' \
    -H "X-goog-api-key: $GEMINI_API_KEY" \  # Get it here https://aistudio.google.com/apikey
    -X POST \
    -d "{
      \"contents\": [
        {
          \"parts\": [
            {
              \"inlineData\": {
                \"data\": \"$B64_IMAGE\",
                \"mimeType\": \"$MIME_TYPE\"
              }
            },
            {
              \"text\": \"$FINAL_PROMPT\"
            }
          ]
        }
      ]
    }" )

  CAPTCHA_TEXT=$(echo "$RESPONSE" | jq -r '.candidates[]?.content?.parts[]?.text')

  if [ -z "$CAPTCHA_TEXT" ]; then
    error "Failed to resolve CAPTCHA or 'jq' extraction error."
  fi

  echo "$CAPTCHA_TEXT"
}

# Create a new account
accountCreate() {
  local firstname=""
  local lastname=""
  local username=""
  local password=""
  local email=""
  
  cli s e && email=${__CLI_S[e]}
  cli c email && email=${__CLI_C[email]}
  
  cli s p && password=${__CLI_S[p]}
  cli c password && password=${__CLI_C[password]}
  
  cli c firstname && firstname=${__CLI_C[firstname]}
  cli c lastname && lastname=${__CLI_C[lastname]}
  cli c username && username=${__CLI_C[username]}
  
  [[ -z "$firstname" ]] && error "First name is required. Use --firstname"
  [[ -z "$lastname" ]] && error "Last name is required. Use --lastname"
  [[ -z "$username" ]] && error "Username is required. Use --username"
  [[ -z "$password" ]] && error "Password is required. Use -p or --password"
  [[ -z "$email" ]] && error "Email is required. Use -e or --email"
  
  [[ ! $username =~ ^[a-zA-Z0-9]{3,16}$ ]] && 
    error "Username must be 3-16 characters and alphanumeric only"
  
  [[ ! $password =~ ^.{4,16}$ ]] &&
    error "Password must be 4-16 characters"
  
  [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}$ ]] &&
    error "Email $(cli color bold red "$email") is not valid"
  
  info "Getting captcha for signup..."
 
  # Get cookies to simulate already being at the signup page (probably not needed)
  curl 'https://freedns.afraid.org/signup/' \
    -c "./account_create_cookies.txt" \
    -o "./account_create_page.html" \
    -L --silent >/dev/null 2>&1
  
  # Get CAPTCHA image
  curl 'https://freedns.afraid.org/securimage/securimage_show.php' \
    -b "./account_create_cookies.txt" \
    -c "./account_create_cookies.txt" \
    -o "./account_create_captcha.png" \
    -L --silent >/dev/null 2>&1
  
  # Install chafa to print captcha directly into terminal
  if ! install_pkg_on_unknown_distro chafa; then
    warning "Unable to install $(cli color bold cyan chafa) to display captcha"
  fi
  
  if command -v chafa &> /dev/null; then
    # 80x30 This same ratio as original image but smaller to fit into screen
    # If you edit the width / height try to keep the same aspect ratio (quality)
    # A.K.A multiply both numbers for the same number: 80x30 * 1.5 === 120x45
    chafa --size 80x30 './account_create_captcha.png'
  else
    info "Captcha saved to: $(cli color bold cyan ./account_create_captcha.png)"
    info "Open the image to see the captcha"
  fi
  
  # Get CAPTCHA from user
  local captchaCode=""
  while [[ -z "$captchaCode" ]]; do
    read -r -p "$(cli color cyan "Enter captcha text"): " captchaCode
  done
  
  info "Creating account $(cli color bold cyan "$username")..."
  
  # Submit signup request
  curl -X POST 'https://freedns.afraid.org/signup/?step=2' \
    -b "./account_create_cookies.txt" \
    -c "./account_create_cookies.txt" \
    -d "plan=starter" \
    -d "firstname=$firstname" \
    -d "lastname=$lastname" \
    -d "username=$username" \
    -d "password=$password" \
    -d "password2=$password" \
    -d "email=$email" \
    -d "captcha_code=$captchaCode" \
    -d "tos=1" \
    -d "action=signup" \
    -d "send=Send+activation+email" \
    -o "./account_create_response.html" \
    -L --silent >/dev/null 2>&1
  
  # Check for errors in response
  if grep -q "The security code was incorrect" "./account_create_response.html"; then
    rm -f "./account_create_cookies.txt" "./account_create_captcha.png" \
      "./account_create_page.html" "./account_create_response.html"
    error "Captcha $(cli color bold red "$captchaCode") was wrong. Try again"
  fi
  
  if grep -q "Username already exists" "./account_create_response.html" || 
     grep -q "Username in use" "./account_create_response.html"; then
    rm -f "./account_create_cookies.txt" "./account_create_captcha.png" \
      "./account_create_page.html" "./account_create_response.html"
    error "Username $(cli color bold red "$username") is already taken. Choose another"
  fi
  
  if grep -q "That e-mail is in use" "./account_create_response.html"; then
    rm -f "./account_create_cookies.txt" "./account_create_captcha.png" \
      "./account_create_page.html" "./account_create_response.html"
    error "Email $(cli color bold red "$email") is already registered"
  fi

  # If we got here, account creation was likely successful
  success "Account created"
  info "Activation email sent to: $(cli color bold cyan "$email")"
  warning "Check your spam folder if you don't see it in your inbox."
  echo ""
  
  # Ask for activation code
  local activationLink=""
  info "Open your email and find the activation link. Email takes around 30s to be available in your Spam folder"
  info "You can paste the activation link here or in your browser. Link should be something like $(cli color bold cyan "http://freedns.afraid.org/signup/activate.php?QWuZMkdyws2IlIWJSdowxMHBa")"
  echo ""
  
  while [[ -z "$activationLink" ]]; do
    read -r -p "$(cli color cyan "Enter URL"): " activationLink
  done
  
  info "Activating account with URL: $(cli color bold cyan "$activationLink")"
  
  # Activate account
  curl "$activationLink" \
    -b "./account_create_cookies.txt" \
    -c "./account_create_cookies.txt" \
    -L --silent >/dev/null 2>&1

  # Not saving response. Asuming accoint activation worked
  # -o "./account_activate_response.html" \

  # Cleanup
  rm -f "./account_create_cookies.txt" "./account_create_captcha.png" \
    "./account_create_page.html" "./account_create_response.html" \
    "./account_activate_response.html"

  echo ""
  exit "Account activated. Use next command to log in.

./freedns.sh $(cli color bold green account) $(cli color bold cyan login) -e $email -p $password 

If you can't log in, try the link $(cli color bold cyan "$activationLink") directly on any browser"
}

# Log into the account (A.K.A get the session cookies) 
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

  # Try to log into the account
  [[ -f './freednsresponse.html' ]] &&  rm './freednsresponse.html';
  curl -X POST 'https://freedns.afraid.org/zc.php?step=2' \
  -d "username=$email" \
  -d "password=$password" \
  -d "remember=1" \
  -d "action=auth" \
  -c "./cookies.txt" \
  -o './freednsresponse.html' \
  -L --silent
 
  # Find "Logged in as" text into the html response to confirm user is logged in.
  grep -q 'Logged in as ' './freednsresponse.html' ||  (rm './cookies.txt' && error "Unable to login. Make sure your credentials are correct.
  Email: $(cli color bold cyan "$email") 
  Password: $(cli color bold cyan "$password")

  If everything is right check the file $(cli color bold cyan "./freednsresponse.html")");


  # Here user logged in sucessfully
  [[ -f './freednsresponse.html' ]] &&  rm './freednsresponse.html';
  
  exit "$(cli color bold bright_cyan AUTHENTICATED.) $(cli color cyan You are now logged in)"

}

accountStatus() {
  warning "Not implemented"
}

accountLogout() {
  [[ -f './cookies.txt' ]] && rm -f './cookies.txt' 
  info "You are logged out"
  builtin exit
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

domainDelete() {
  warning "Not implemented"
}

subdomainAvailable() {
  local config_file="subdomainList.config"
  local total=$(wc -l < "$config_file")

  if [[ ! -f "$config_file" ]]; then
    error "No available domains. Config file $(cli color bold yellow "$config_file") not found"
    return 1
  fi

  echo ""
  echo "Popular domains offering subdomains"
  echo "$(cli color bold white "  -----------------------------------------------------------------------")"
  echo ""

  local coloredDomain=0
  local input_data=""

  while IFS=' ' read -r domain _; do
    
    if [[ $coloredDomain -eq 0 ]]; then
      local colored_domain="$(cli color bold yellow "$domain")" 
    else
      local colored_domain="$(cli color bold cyan "$domain")"
    fi

    input_data+="$colored_domain\n" 
    coloredDomain=$(( 1 - coloredDomain ))
  done < "$config_file"

  echo -e "$input_data" | awk '
  {
    line = $0
    temp_line = line
    
    gsub(/\x1b\[[0-9;]*m/, "", temp_line)
    
    len = length(temp_line)
    
    columnas = 3
    ancho_columna = 26 
    
    padding = ancho_columna - len

    printf("  %s", line)
    
    for (i = 0; i < padding; i++) {
      printf(" ")
    }

    if (NR % columnas == 0) {
      printf("\n\n")
    }
  }
  END {
    if (NR % columnas != 0) {
      printf("\n")
    }
  }'

  echo ""
  echo "$(cli color bold white "  -----------------------------------------------------------------------")"
  echo ""
  info "Found $(cli color cyan "$total") domains available"
}

subdomainCreate() {
  # TODO Only info on -v or -d
  info 'Getting captcha ...'
  curl 'https://freedns.afraid.org/securimage/securimage_show.php' \
  -b "./cookies.txt" \
  -c "./cookies.txt" \
  -o "./freednsCaptchaResponse.png" \
  -L --silent

  if ! install_pkg_on_unknown_distro chafa; then
    error "Unable to find package manager to install $(cli color bold cyan "chafa"), please do manually."
fi 
  if ! install_pkg_on_unknown_distro jq; then
    error "Unable to find package manager to install $(cli color bold cyan "jq"), please do manually."
  fi

  chafa --size 80x30 './freednsCaptchaResponse.png'

  # info "Trying to solve captcha using AI"
  local captchaCode=""
  # captchaCode=$(resolveCaptcha './freednsCaptchaResponse.png')
  # info "Captcha resolved by AI: $(cli color bold cyan "$captchaCode")";

  read -r -p "Please, enter the captcha text and press enter: " captchaCode
  # TODO: Try OCR instead of AI to complete captcha.

  # echo "Captcha is: $captchaCode"

  local domainID=29;
  local domain="";
  local subdomain=""
  local address="127.0.0.1"
  local record="A"

  cli c domain && domain=${__CLI_C[domain]}
  domainID=$(getSubdomainID $domain)

  cli s s && subdomain=${__CLI_S[s]}
  cli c subdomain && subdomain=${__CLI_C[subdomain]}

  cli s a && address=${__CLI_S[a]}
  cli c address && address=${__CLI_C[address]}

  cli s r && record=${__CLI_S[r]}
  cli c record && record=${__CLI_C[record]}

  info "Record:$(cli color bold cyan $record). Address:$(cli color bold cyan $address). Captcha:$(cli color bold cyan $captchaCode). DomainID:$(cli color bold cyan $domainID)"

  curl -X POST 'https://freedns.afraid.org/subdomain/save.php?step=2' \
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
  -o "./freedns_subdomain_creation_response.html" \
  -L --silent 
  
  grep -q 'The security code was incorrect, please try again' './freedns_subdomain_creation_response.html' && error "The captcha $(cli color bold red "$captchaCode") was wrong. Try again"
  grep -q "The hostname <b>$subdomain.$domain</b> is already taken!" './freedns_subdomain_creation_response.html' && error "The domain $(cli color bold cyan "$subdomain").$(cli color bold yellow "$domain") is already taken by someone else."
  grep -q '<TITLE>Problems!</TITLE>' './freedns_subdomain_creation_response.html' && error "Unable to create the subdomain $(cli color bold cyan "$subdomain").$(cli color bold yellow "$domain") for unknown reassons
 
Make sure you are logged in
"

  rm './freedns_subdomain_creation_response.html'
  exit "Subdomain $(cli color bold cyan "$subdomain").$(cli color bold yellow "$domain") created"

}

subdomainList() {
  warning "Not implemented"
}

subdomainEdit() {
  warning "Not implemented"
}

subdomainDelete() {
  warning "Not implemented"
}

cmd=$(cli o | sed -n '1p')
subcmd=$(cli o | sed -n '2p')
subsubcmd=$(cli o | sed -n '3p')

if      cli noArgs                 ;then    showUsage                 ;fi
if cli s h || cli c help           ;then    showUsage                 ;fi
if cli s v || cli c verbose        ;then    verbose=true              ;fi
if cli s d || cli c debug          ;then    debug=true                ;fi 
if            cli c version        ;then    exit "$version"           ;fi


if [[ $cmd =~ ^account$        ]]  ;then
  if [[ $subcmd =~ ^create$    ]]  ;then    accountCreate             ;elif 
     [[ $subcmd =~ ^login$     ]]  ;then    accountLogin              ;elif
     [[ $subcmd =~ ^status$    ]]  ;then    accountStatus             ;elif
     [[ $subcmd =~ ^logout$    ]]  ;then    accountLogout             ;elif
     [[ $subcmd =~ ^edit$      ]]  ;then    accountEdit               ;elif
     [[ $subcmd =~ ^delete$    ]]  ;then    accountDelete             ;else
     [[    -z $subcmd          ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green account)" ;
  fi 

elif [[ $cmd =~ ^domain$       ]]  ;then  
  if [[ $subcmd =~ ^create$    ]]  ;then    domainCreate              ;elif
     [[ $subcmd =~ ^list$      ]]  ;then    domainList                ;elif
     [[ $subcmd =~ ^delete$    ]]  ;then    domainDelete              ;elif
     [[ $subcmd =~ ^edit$      ]]  ;then    domainEdit                ;else
     [[    -z $subcmd          ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green domain)" ;
  fi

elif [[ $cmd =~ ^subdomain$    ]]  ;then
  if [[ $subcmd =~ ^available$ ]]  ;then    subdomainAvailable        ;elif
     [[ $subcmd =~ ^create$    ]]  ;then    subdomainCreate           ;elif
     [[ $subcmd =~ ^list$      ]]  ;then    subdomainList             ;elif
     [[ $subcmd =~ ^delete$    ]]  ;then    subdomainDelete           ;elif
     [[ $subcmd =~ ^edit$      ]]  ;then    subdomainEdit             ;else
     [[    -z $subcmd          ]]    &&     error "You need to provide a subcommand" ||
       error "The subcommand $(cli color bold red $subcmd) is not valid for $(cli color bold green subdomain)" ;
  fi

elif [[ $cmd =~ ^help$         ]]  ;then    showUsage 

else
  error "The command $(cli color bold red $cmd) is not a valid command"
fi


