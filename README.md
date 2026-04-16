# ✦•┈๑⋅⋯ 𝐏𝐎𝐂-𝐀𝐢𝐓𝐌 ⋯⋅๑┈•✦

<img src="https://i.pinimg.com/1200x/4d/6b/d3/4d6bd38e850925dbc2ff1ca106377edd.jpg?width=770&height=578&fit=crop&format=pjpg&auto=webp" alt="img" align="right" width="400px"> <br><br>



This project is a proof of concept (POC) demonstrating an Adversary-in-the-Middle (AiTM) attack. It simulates a phishing scenario where an attacker uses a proxy to intercept user credentials between a victim and a legitimate Identity Provider (IdP), such as Microsoft authentication services. The POC highlights how easily such attacks can be executed using modern deployment tools like Railway or Coolify, combined with minimal technical knowledge and AI-assisted configuration.

The project is built using Ruby and the Sinatra web framework, with components for the IdP simulation, the AiTM proxy, and an attacker dashboard.


<br><br><br>

##  【𝑪𝒐𝒎𝒑𝒐𝒏𝒆𝒏𝒕𝒔】

### 1. Identity Provider (IdP) - `idp/`

- **Purpose**: Simulates a legitimate authentication service (e.g., Microsoft login).
- **Features**:
  - User authentication with predefined credentials.
  - JWT token generation and validation.
  - Session management.
- **Database**: Stores captured tokens in `tokens.db`.
- **Configuration**: Loads secrets from `token.json`.

### 2. Proxy (AiTM) - `proxy/`

- **Purpose**: Acts as the intermediary that rewrites URLs and captures credentials.
- **Features**:
  - Rewrites HTML content to redirect requests through the proxy.
  - Captures user credentials, tokens, IP addresses, and user agents.
  - Stores captured data in `captured_credentials.db`.
- **Configuration**: Uses environment variables for IdP and proxy URLs.

### 3. Attacker Dashboard - `attacker/`

- **Purpose**: Provides a web interface for the attacker to view captured credentials.
- **Features**:
  - Displays captured credentials in reverse chronological order.
  - Decodes JWT tokens for inspection.
  - Shows validity of tokens.
- **Database**: Reads from the shared `captured_credentials.db`.

## 【𝑺𝒆𝒕𝒖𝒑 𝒂𝒏𝒅 𝑰𝒏𝒔𝒕𝒂𝒍𝒍𝒂𝒕𝒊𝒐𝒏】

### Prerequisites

- Ruby 3.3.0
- Bundler (for gem management)
- SQLite3

### 【𝑰𝒏𝒔𝒕𝒂𝒍𝒍𝒂𝒕𝒊𝒐𝒏 𝑺𝒕𝒆𝒑𝒔】

1. Clone the repository.
2. Navigate to the project directory.
3. Install dependencies:

   ```bash
   bundle install
   ```

4. Configure environment variables (optional, defaults provided):
   - `IDP_URL`: URL for the IdP server (default: `http://localhost:4444`)
   - `PROXY_URL`: URL for the proxy server (default: `http://localhost:4445`)
5. Ensure `token.json` files are present in `idp/` and `attacker/` directories with JWT secrets.

### 【𝑹𝒖𝒏𝒏𝒊𝒏𝒈 𝒕𝒉𝒆 𝑨𝒑𝒑𝒍𝒊𝒄𝒂𝒕𝒊𝒐𝒏】

1. Start the IdP server:

   ```bash
   cd idp
   rackup config.ru -p 4444
   ```

2. Start the Proxy server:

   ```bash
   cd proxy
   rackup config.ru -p 4445
   ```

3. Start the Attacker Dashboard:

   ```bash
   cd attacker
   rackup config.ru -p 4446
   ```

### 【𝑼𝒔𝒂𝒈𝒆】

- Access the proxy at `http://localhost:4445/login` to simulate the phishing page.
- Victims enter credentials, which are captured by the proxy.
- Attackers view captured data at `http://localhost:4446`.

## 【𝑫𝒆𝒑𝒆𝒏𝒅𝒆𝒏𝒄𝒊𝒆𝒔】

- Sinatra: Web framework
- Puma: HTTP server
- SQLite3: Database
- Sequel: ORM for database interactions
- JWT: JSON Web Token handling
- Faraday: HTTP client
- Rack-Session: Session management
- Dotenv: Environment variable loading
