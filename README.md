# Ansible_deployment_automation


## 🎯 What This Project Does (High Level)

This project automates the deployment of a Java Spring Boot application:
1. Takes source code from GitHub
2. Builds it with Maven
3. Creates a Docker image
4. Pushes it to Docker Hub

All of this happens automatically on your AWS EC2 instances!

---

## 📋 Complete Flow: Step-by-Step

### Phase 1: Prerequisites & Setup (One-Time)

```
YOU (Developer)
    │
    ├─→ Create AWS EC2 instances
    │   └─→ Tag them: Environment=dev, Role=web
    │
    ├─→ Configure AWS credentials on your laptop
    │   └─→ aws configure (or export AWS keys)
    │
    ├─→ Install Ansible on your laptop
    │   └─→ pip install ansible
    │
    ├─→ Install dependencies
    │   └─→ make install (or run commands manually)
    │
    └─→ Create vault.yaml with Docker credentials
        └─→ ansible-vault create vault.yaml
```

---

### Phase 2: Execution Flow (When You Run `make deploy`)

```
┌─────────────────────────────────────────────────────────────────┐
│  YOU TYPE: make deploy                                          │
│  (or: ansible-playbook site.yaml -u ubuntu --ask-vault-pass)   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: Ansible Reads Configuration Files                      │
├─────────────────────────────────────────────────────────────────┤
│  • ansible.cfg        → Settings (inventory location, SSH opts) │
│  • site.yaml          → What to do (the playbook)              │
│  • group_vars/all.yaml → Variables (URLs, paths, versions)     │
│  • vault.yaml         → Secrets (Docker credentials)           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: Discover Target Hosts (Dynamic Inventory)              │
├─────────────────────────────────────────────────────────────────┤
│  File: inventory/aws_ec2.yaml                                   │
│                                                                  │
│  Ansible → Calls AWS API                                        │
│         → Finds EC2 instances with:                             │
│            • Tag Environment=dev                                │
│            • Tag Role=web                                       │
│            • State=running                                      │
│         → Gets public IP addresses                              │
│         → Groups them as "env_dev"                              │
│                                                                  │
│  Result: List of target servers to configure                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: Pre-Tasks (site.yaml)                                  │
├─────────────────────────────────────────────────────────────────┤
│  For each discovered EC2 instance:                              │
│                                                                  │
│  1. Wait for SSH connection (timeout: 300s)                     │
│     └─→ Ensures server is ready                                │
│                                                                  │
│  2. Update apt cache                                            │
│     └─→ apt update (with 1-hour cache)                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STEP 4: Execute Role - deploy_app                              │
│  (This is where the real work happens!)                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.1: Install System Packages   │
        ├─────────────────────────────────────────┤
        │  SSH into EC2 → Run:                    │
        │  apt install:                           │
        │    • openjdk-17-jdk                     │
        │    • git                                │
        │    • curl                               │
        │    • python3-pip                        │
        │                                         │
        │  Then: pip install docker requests      │
        │  (Needed for Ansible Docker modules)    │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.2: Install Maven             │
        ├─────────────────────────────────────────┤
        │  Check: Is Maven already installed?     │
        │         /opt/apache-maven-3.8.7/bin/mvn │
        │                                         │
        │  If NO:                                 │
        │    1. Download Maven 3.8.7 from Apache  │
        │    2. Extract to /opt/                  │
        │    3. Create /etc/profile.d/maven.sh    │
        │       (using maven.sh.j2 template)      │
        │       Sets: JAVA_HOME, M2_HOME, PATH    │
        │                                         │
        │  If YES:                                │
        │    Skip (idempotent!)                   │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.3: Configure Docker          │
        ├─────────────────────────────────────────┤
        │  1. Start Docker service                │
        │     systemctl start docker              │
        │     systemctl enable docker             │
        │                                         │
        │  2. Add 'ubuntu' user to 'docker' group │
        │     usermod -aG docker ubuntu           │
        │                                         │
        │  3. Trigger handler: reset SSH          │
        │     (So user can run docker commands)   │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.4: Clone Git Repository      │
        ├─────────────────────────────────────────┤
        │  URL: github.com/jaiswaladi246/Boardgame│
        │  Destination: /home/ubuntu/Boardgame    │
        │  Branch: main                           │
        │                                         │
        │  If repo exists: git pull (update)      │
        │  If repo missing: git clone             │
        │                                         │
        │  User: ubuntu (not root)                │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.5: Build with Maven          │
        ├─────────────────────────────────────────┤
        │  Command: mvn clean package -DskipTests │
        │  Directory: /home/ubuntu/Boardgame      │
        │  Environment:                           │
        │    JAVA_HOME=/usr/lib/jvm/java-17...    │
        │    M2_HOME=/opt/apache-maven-3.8.7      │
        │                                         │
        │  What happens:                          │
        │    1. Maven downloads dependencies      │
        │    2. Compiles Java code                │
        │    3. Runs tests (skipped with flag)    │
        │    4. Packages as .jar or .war file     │
        │                                         │
        │  Output: target/*.jar                   │
        │                                         │
        │  If build fails: Show error & stop      │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.6: Build Docker Image        │
        ├─────────────────────────────────────────┤
        │  1. Login to Docker Hub                 │
        │     username: (from vault.yaml)         │
        │     password: (from vault.yaml)         │
        │     [Credentials hidden in logs]        │
        │                                         │
        │  2. Build Docker image                  │
        │     docker build -t adijaiswal/board... │
        │     Location: /home/ubuntu/Boardgame    │
        │     Uses: Dockerfile in the repo        │
        │                                         │
        │  3. Tag image                           │
        │     adijaiswal/board:latest             │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.7: Push to Docker Hub        │
        ├─────────────────────────────────────────┤
        │  docker push adijaiswal/board:latest    │
        │                                         │
        │  Image is now available publicly at:    │
        │  hub.docker.com/r/adijaiswal/board      │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  SUBSTEP 4.8: Cleanup                   │
        ├─────────────────────────────────────────┤
        │  1. Logout from Docker Hub              │
        │     (Remove stored credentials)         │
        │                                         │
        │  2. Prune old Docker images             │
        │     docker image prune -f               │
        │     (Free up disk space)                │
        └─────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STEP 5: Post-Tasks (site.yaml)                                 │
├─────────────────────────────────────────────────────────────────┤
│  Display deployment summary:                                    │
│    ✓ Deployment completed successfully!                        │
│    ✓ Docker image: adijaiswal/board:latest                     │
│    ✓ Repository: github.com/jaiswaladi246/Boardgame           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  DONE! ✓                                                        │
│                                                                  │
│  Your application is now:                                       │
│    • Built from source                                          │
│    • Packaged as Docker image                                   │
│    • Pushed to Docker Hub                                       │
│    • Ready to run anywhere!                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 How Files Work Together

```
ansible.cfg
├─→ Points to inventory/aws_ec2.yaml (where are my servers?)
├─→ Configures SSH (how to connect?)
└─→ Enables caching (performance boost)

site.yaml (Main Playbook)
├─→ Reads group_vars/all.yaml (what values to use?)
├─→ Reads vault.yaml (what are my secrets?)
├─→ Targets hosts: env_dev (which servers?)
└─→ Calls role: deploy_app (what to do?)

inventory/aws_ec2.yaml
├─→ Queries AWS API (find EC2 instances)
├─→ Filters by tags (Environment=dev, Role=web)
└─→ Returns list of IPs (these are your targets)

group_vars/all.yaml
└─→ Provides variables to ALL tasks:
    • git_repo_url
    • docker_image_name
    • maven_version
    • etc.

vault.yaml (encrypted)
└─→ Provides secrets:
    • docker_username
    • docker_password

roles/deploy_app/
├─→ tasks/main.yaml (the actual work)
├─→ handlers/main.yaml (reactions to changes)
└─→ templates/maven.sh.j2 (config file template)
```

---

## 🎮 Control Flow (Decision Making)

```
For each EC2 instance:
    
    Is Maven installed?
    ├─→ YES: Skip installation
    └─→ NO:  Download & install
    
    Does Git repo exist?
    ├─→ YES: git pull (update)
    └─→ NO:  git clone (new)
    
    Did Maven build succeed?
    ├─→ YES: Continue to Docker
    └─→ NO:  Show error & STOP
    
    Did Docker build succeed?
    ├─→ YES: Push to Docker Hub
    └─→ NO:  Show error & STOP
    
    Were new images created?
    ├─→ YES: Prune old images
    └─→ NO:  Skip cleanup
```

---

## 🔐 Security Flow

```
vault.yaml (Encrypted)
    │
    │ You type vault password
    ↓
Ansible decrypts in memory
    │
    │ Passes to Docker login task
    ↓
Docker Hub authentication
    │
    │ After push completes
    ↓
Docker logout (remove credentials)
    │
    │ No credentials stored!
    ✓
```

---

## 🔄 Idempotency Explained

Run the playbook multiple times → Same result!

```
First Run:
  ├─→ Install Maven ✓
  ├─→ Clone repo ✓
  ├─→ Build app ✓
  └─→ Push image ✓

Second Run:
  ├─→ Maven already installed ⏭️ (Skip)
  ├─→ Repo already exists ⏭️ (Pull updates)
  ├─→ Build only if code changed ⏭️
  └─→ Push only if image changed ⏭️

Third Run:
  └─→ Everything up to date ⏭️ (Nothing to do!)
```

This means it's **SAFE** to run repeatedly!

---

## Summary: The Big Picture

```
┌─────────────┐
│  You type:  │
│ make deploy │
└──────┬──────┘
       │
       ↓
┌─────────────────────────────────────┐
│ Ansible orchestrates everything:    │
│ 1. Find servers (AWS)               │
│ 2. Install tools (Java, Maven)      │
│ 3. Get code (GitHub)                │
│ 4. Build app (Maven)                │
│ 5. Create image (Docker)            │
│ 6. Publish (Docker Hub)             │
└──────┬──────────────────────────────┘
       │
       ↓
┌─────────────────────────────────────┐
│ Result: Automated CI/CD pipeline!   │
│ • Repeatable                        │
│ • Consistent                        │
│ • Fast                              │
│ • No manual steps                   │
└─────────────────────────────────────┘
```

This is **Infrastructure as Code** and **Continuous Deployment** in action! 🚀
