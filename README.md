# Proxy as an intermediary [Proof of concept]

This project is a proof of concept (POC) demonstrating an Adversary-in-the-Middle (AiTM) attack. It simulates a phishing scenario where an attacker uses a proxy to intercept user credentials between a victim and a legitimate Identity Provider (IdP), such as Microsoft authentication services. The POC highlights how easily such attacks can be executed using modern deployment tools like Railway or Coolify, combined with minimal technical knowledge and AI-assisted configuration.

The project is built using Ruby and the Sinatra web framework, with components for the IdP simulation, the AiTM proxy, and an attacker dashboard.

<br><br>


<img src="https://i.pinimg.com/736x/fa/b7/37/fab7379fbf5ba04a9fe2cd72da46c4a3.jpg?width=770&height=578&fit=crop&format=pjpg&auto=webp" alt="img" align="right" width="400px"> <br><br>

## Components

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

## Setup and Installation

### Prerequisites

- Ruby 3.3.0
- Bundler (for gem management)
- SQLite3

### Installation Steps

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

### Running the Application

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

### Usage

- Access the proxy at `http://localhost:4445/login` to simulate the phishing page.
- Victims enter credentials, which are captured by the proxy.
- Attackers view captured data at `http://localhost:4446`.

## Security Considerations

This is a proof of concept for educational purposes only. It demonstrates vulnerabilities in authentication flows and should not be used for malicious activities. In a real-world scenario:

- Always use HTTPS.
- Implement proper input validation and sanitization.
- Store secrets securely (e.g., via environment variables, not files).
- Regularly update dependencies to patch security vulnerabilities.

## Dependencies

- Sinatra: Web framework
- Puma: HTTP server
- SQLite3: Database
- Sequel: ORM for database interactions
- JWT: JSON Web Token handling
- Faraday: HTTP client
- Rack-Session: Session management
- Dotenv: Environment variable loading

## Roadmap

- [x] Target page
- [x] Enhance proxy realism
- [x] Attacker dashboard
- [x] Ignore file for database and tokens
- [x] JSON configuration for tokens and secrets
- [x] Comprehensive documentation (this file)
- [ ] Fix proxy -> Attacker danshboard information sending issue
- [ ] Unit tests
- [ ] Docker containerization

## License

This project is for educational purposes. Use responsibly.
