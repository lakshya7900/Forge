# ⚒️ Forge

**Forge** is an **AI-powered project planning and collaboration platform for developers**. It helps teams move from idea to execution by intelligently analyzing team skills, project goals, and progress to generate tech stack recommendations, role assignments, and task breakdowns — all in one place.

Instead of manually deciding who does what and which tools to use, Forge acts as a smart project planner that evolves with your project.

---

## 🚀 Features

- 👤 **Skill-Based User Profiles**: Developers list their tech stack skills with proficiency levels  
- 👥 **Team Project Creation**: Create projects and add existing users as collaborators  
- 🧠 **AI-Driven Tech Stack Selection**: Recommends the best tools based on project goals and team strengths  
- 🧩 **Automatic Role Assignment**: Suggests ownership for frontend, backend, infrastructure, etc.  
- 📝 **Intelligent Task Breakdown**: Generates ordered tasks with clear ownership and priorities  
- 🔄 **Adaptive Planning**: Continuously suggests improvements, new features, and task changes as the project evolves  
- 🖥️ **Developer-Centric UX**: Designed specifically for software teams, not generic project management  

---

## 🛠️ Tech Stack

- **Frontend**: Swift & SwiftUI (macOS application)  
- **Backend**: Go (REST APIs)  
- **Database**: PostgreSQL  
- **AI**: Apple Developer AI Frameworks (on-device intelligence)  
- **Authentication**: JWT-based authentication  

---

## ⚡ Getting Started

### Prerequisites

- macOS  
- Xcode  
- Go >= 1.21  
- PostgreSQL  

### Installation

1. Clone the repository:

```bash
git clone https://github.com/lakshya7900/forge.git
```

2. Start the backend server:

```bash
cd Backend
go mod tidy
go run main.go
```

3. Open the frontend app in XCode

4. Build and run the app

## 🎯 Usage
1. Create a user profile and add your technical skills
2. Start a new project and invite other users
3. Describe the project goals
4. Let Forge generate:
	-	Recommended tech stack
	-	Role assignments
	-	Initial task breakdown
5. Track progress and receive AI-driven suggestions as the project evolves

## 🤝 Contributing
We welcome contributions!
1. Fork the repository
2. Create a branch: ```git checkout -b feature/YourFeature```
3. Commit your changes: ```git commit -m 'Add new feature'```
4. Push to the branch: ```git push origin feature/YourFeature```
5. Open a Pull Request

## 📄 License
This project is licensed under the **MIT License**. See the LICENSE file for details.
