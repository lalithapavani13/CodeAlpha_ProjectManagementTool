# Create folder structure
New-Item -ItemType Directory -Force -Path "backend/models"
New-Item -ItemType Directory -Force -Path "backend/routes"
New-Item -ItemType Directory -Force -Path "backend/middleware"
New-Item -ItemType Directory -Force -Path "frontend/css"
New-Item -ItemType Directory -Force -Path "frontend/js"

# ========== backend/package.json ==========
@'
{
  "name": "project-management-tool",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "mongoose": "^7.3.1",
    "socket.io": "^4.6.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
'@ | Set-Content backend/package.json

# ========== backend/.env ==========
@'
PORT=5000
MONGO_URI=mongodb://localhost:27017/projectmanagement
JWT_SECRET=supersecretkey123
'@ | Set-Content backend/.env

# ========== backend/server.js ==========
@'
const express = require("express");
const http = require("http");
const socketio = require("socket.io");
const mongoose = require("mongoose");
const cors = require("cors");
const path = require("path");
require("dotenv").config();

const app = express();
const server = http.createServer(app);
const io = socketio(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "../frontend")));

mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log(err));

app.use("/api/auth", require("./routes/auth"));
app.use("/api/projects", require("./routes/projects"));
app.use("/api/tasks", require("./routes/tasks"));
app.use("/api/comments", require("./routes/comments"));

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("joinProject", (projectId) => {
    socket.join(projectId);
  });

  socket.on("taskUpdated", (data) => {
    io.to(data.projectId).emit("taskUpdated", data);
  });

  socket.on("commentAdded", (data) => {
    io.to(data.projectId).emit("commentAdded", data);
  });

  socket.on("notification", (data) => {
    io.to(data.projectId).emit("notification", data);
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
'@ | Set-Content backend/server.js

# ========== backend/middleware/auth.js ==========
@'
const jwt = require("jsonwebtoken");

module.exports = function (req, res, next) {
  const token = req.header("Authorization");
  if (!token) return res.status(401).json({ msg: "No token, authorization denied" });
  try {
    const decoded = jwt.verify(token.replace("Bearer ", ""), process.env.JWT_SECRET);
    req.user = decoded.user;
    next();
  } catch (err) {
    res.status(401).json({ msg: "Token is not valid" });
  }
};
'@ | Set-Content backend/middleware/auth.js

# ========== backend/models/User.js ==========
@'
const mongoose = require("mongoose");
const UserSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model("User", UserSchema);
'@ | Set-Content backend/models/User.js

# ========== backend/models/Project.js ==========
@'
const mongoose = require("mongoose");
const ProjectSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String },
  owner: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  createdAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model("Project", ProjectSchema);
'@ | Set-Content backend/models/Project.js

# ========== backend/models/Task.js ==========
@'
const mongoose = require("mongoose");
const TaskSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String },
  status: { type: String, enum: ["todo", "inprogress", "done"], default: "todo" },
  project: { type: mongoose.Schema.Types.ObjectId, ref: "Project" },
  assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  createdAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model("Task", TaskSchema);
'@ | Set-Content backend/models/Task.js

# ========== backend/models/Comment.js ==========
@'
const mongoose = require("mongoose");
const CommentSchema = new mongoose.Schema({
  text: { type: String, required: true },
  task: { type: mongoose.Schema.Types.ObjectId, ref: "Task" },
  project: { type: mongoose.Schema.Types.ObjectId, ref: "Project" },
  author: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  createdAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model("Comment", CommentSchema);
'@ | Set-Content backend/models/Comment.js

# ========== backend/routes/auth.js ==========
@'
const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");

router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ msg: "User already exists" });
    user = new User({ name, email, password });
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(password, salt);
    await user.save();
    const payload = { user: { id: user.id } };
    jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: "7d" }, (err, token) => {
      if (err) throw err;
      res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    });
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    let user = await User.findOne({ email });
    if (!user) return res.status(400).json({ msg: "Invalid credentials" });
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ msg: "Invalid credentials" });
    const payload = { user: { id: user.id } };
    jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: "7d" }, (err, token) => {
      if (err) throw err;
      res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    });
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

module.exports = router;
'@ | Set-Content backend/routes/auth.js

# ========== backend/routes/projects.js ==========
@'
const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const Project = require("../models/Project");

router.get("/", auth, async (req, res) => {
  try {
    const projects = await Project.find({
      $or: [{ owner: req.user.id }, { members: req.user.id }]
    }).populate("owner", "name email").populate("members", "name email");
    res.json(projects);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.post("/", auth, async (req, res) => {
  try {
    const { name, description } = req.body;
    const project = new Project({ name, description, owner: req.user.id, members: [req.user.id] });
    await project.save();
    res.json(project);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.delete("/:id", auth, async (req, res) => {
  try {
    await Project.findByIdAndDelete(req.params.id);
    res.json({ msg: "Project deleted" });
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

module.exports = router;
'@ | Set-Content backend/routes/projects.js

# ========== backend/routes/tasks.js ==========
@'
const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const Task = require("../models/Task");

router.get("/:projectId", auth, async (req, res) => {
  try {
    const tasks = await Task.find({ project: req.params.projectId })
      .populate("assignedTo", "name email")
      .populate("createdBy", "name email");
    res.json(tasks);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.post("/", auth, async (req, res) => {
  try {
    const { title, description, project, assignedTo } = req.body;
    const task = new Task({ title, description, project, assignedTo, createdBy: req.user.id });
    await task.save();
    res.json(task);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.put("/:id", auth, async (req, res) => {
  try {
    const task = await Task.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(task);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.delete("/:id", auth, async (req, res) => {
  try {
    await Task.findByIdAndDelete(req.params.id);
    res.json({ msg: "Task deleted" });
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

module.exports = router;
'@ | Set-Content backend/routes/tasks.js

# ========== backend/routes/comments.js ==========
@'
const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const Comment = require("../models/Comment");

router.get("/:taskId", auth, async (req, res) => {
  try {
    const comments = await Comment.find({ task: req.params.taskId })
      .populate("author", "name email");
    res.json(comments);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

router.post("/", auth, async (req, res) => {
  try {
    const { text, task, project } = req.body;
    const comment = new Comment({ text, task, project, author: req.user.id });
    await comment.save();
    await comment.populate("author", "name email");
    res.json(comment);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

module.exports = router;
'@ | Set-Content backend/routes/comments.js

# ========== frontend/index.html ==========
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>ProjectHub - Login</title>
  <link rel="stylesheet" href="css/style.css" />
</head>
<body>
  <div class="auth-container">
    <div class="auth-box">
      <h1>🗂 ProjectHub</h1>
      <p class="subtitle">Manage your projects efficiently</p>
      <div class="tabs">
        <button class="tab active" onclick="showTab('login')">Login</button>
        <button class="tab" onclick="showTab('register')">Register</button>
      </div>
      <div id="login" class="form-section">
        <input type="email" id="loginEmail" placeholder="Email" />
        <input type="password" id="loginPassword" placeholder="Password" />
        <button class="btn-primary" onclick="login()">Login</button>
      </div>
      <div id="register" class="form-section hidden">
        <input type="text" id="regName" placeholder="Full Name" />
        <input type="email" id="regEmail" placeholder="Email" />
        <input type="password" id="regPassword" placeholder="Password" />
        <button class="btn-primary" onclick="register()">Register</button>
      </div>
      <p id="authMsg" class="msg"></p>
    </div>
  </div>
  <script src="js/auth.js"></script>
</body>
</html>
'@ | Set-Content frontend/index.html

# ========== frontend/dashboard.html ==========
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>ProjectHub - Dashboard</title>
  <link rel="stylesheet" href="css/style.css" />
</head>
<body>
  <nav class="navbar">
    <h2>🗂 ProjectHub</h2>
    <div class="nav-right">
      <span id="userName"></span>
      <div class="notif-wrapper">
        <button class="notif-btn" onclick="toggleNotifications()">🔔 <span id="notifCount" class="badge hidden">0</span></button>
        <div id="notifDropdown" class="notif-dropdown hidden"></div>
      </div>
      <button class="btn-logout" onclick="logout()">Logout</button>
    </div>
  </nav>
  <div class="dashboard-container">
    <div class="dashboard-header">
      <h2>My Projects</h2>
      <button class="btn-primary" onclick="openModal()">+ New Project</button>
    </div>
    <div id="projectsList" class="projects-grid"></div>
  </div>
  <div id="modal" class="modal hidden">
    <div class="modal-box">
      <h3>Create New Project</h3>
      <input type="text" id="projectName" placeholder="Project Name" />
      <textarea id="projectDesc" placeholder="Description"></textarea>
      <div class="modal-btns">
        <button class="btn-primary" onclick="createProject()">Create</button>
        <button class="btn-secondary" onclick="closeModal()">Cancel</button>
      </div>
    </div>
  </div>
  <script src="/socket.io/socket.io.js"></script>
  <script src="js/dashboard.js"></script>
</body>
</html>
'@ | Set-Content frontend/dashboard.html

# ========== frontend/project.html ==========
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>ProjectHub - Board</title>
  <link rel="stylesheet" href="css/style.css" />
</head>
<body>
  <nav class="navbar">
    <h2><a href="dashboard.html" class="back-link">← </a>🗂 <span id="projectTitle"></span></h2>
    <div class="nav-right">
      <span id="userName"></span>
      <div class="notif-wrapper">
        <button class="notif-btn" onclick="toggleNotifications()">🔔 <span id="notifCount" class="badge hidden">0</span></button>
        <div id="notifDropdown" class="notif-dropdown hidden"></div>
      </div>
      <button class="btn-logout" onclick="logout()">Logout</button>
    </div>
  </nav>
  <div class="board-container">
    <div class="board-header">
      <h3>Kanban Board</h3>
      <button class="btn-primary" onclick="openTaskModal()">+ Add Task</button>
    </div>
    <div class="kanban-board">
      <div class="kanban-col">
        <h4>📋 To Do</h4>
        <div id="todo" class="task-list"></div>
      </div>
      <div class="kanban-col">
        <h4>⚙️ In Progress</h4>
        <div id="inprogress" class="task-list"></div>
      </div>
      <div class="kanban-col">
        <h4>✅ Done</h4>
        <div id="done" class="task-list"></div>
      </div>
    </div>
  </div>
  <div id="taskModal" class="modal hidden">
    <div class="modal-box">
      <h3>Add New Task</h3>
      <input type="text" id="taskTitle" placeholder="Task Title" />
      <textarea id="taskDesc" placeholder="Description"></textarea>
      <div class="modal-btns">
        <button class="btn-primary" onclick="createTask()">Create</button>
        <button class="btn-secondary" onclick="closeTaskModal()">Cancel</button>
      </div>
    </div>
  </div>
  <div id="commentModal" class="modal hidden">
    <div class="modal-box">
      <h3>Task Comments</h3>
      <div id="commentsList" class="comments-list"></div>
      <div class="comment-input">
        <input type="text" id="commentText" placeholder="Write a comment..." />
        <button class="btn-primary" onclick="addComment()">Send</button>
      </div>
      <button class="btn-secondary" onclick="closeCommentModal()" style="margin-top:10px">Close</button>
    </div>
  </div>
  <script src="/socket.io/socket.io.js"></script>
  <script src="js/project.js"></script>
</body>
</html>
'@ | Set-Content frontend/project.html

# ========== frontend/css/style.css ==========
@'
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: "Segoe UI", sans-serif; background: #f0f2f5; color: #333; }
a { text-decoration: none; color: inherit; }

/* AUTH */
.auth-container { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: linear-gradient(135deg, #667eea, #764ba2); }
.auth-box { background: white; padding: 40px; border-radius: 16px; width: 380px; box-shadow: 0 20px 60px rgba(0,0,0,0.2); }
.auth-box h1 { text-align: center; font-size: 28px; margin-bottom: 6px; }
.subtitle { text-align: center; color: #888; margin-bottom: 24px; }
.tabs { display: flex; margin-bottom: 20px; border-radius: 8px; overflow: hidden; border: 1px solid #ddd; }
.tab { flex: 1; padding: 10px; border: none; cursor: pointer; background: #f5f5f5; font-size: 14px; }
.tab.active { background: #667eea; color: white; }
.form-section input, .form-section textarea { width: 100%; padding: 12px; margin-bottom: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; }
.hidden { display: none !important; }
.msg { text-align: center; margin-top: 10px; color: red; font-size: 13px; }

/* BUTTONS */
.btn-primary { background: #667eea; color: white; border: none; padding: 12px 20px; border-radius: 8px; cursor: pointer; width: 100%; font-size: 15px; transition: background 0.2s; }
.btn-primary:hover { background: #5a6fd6; }
.btn-secondary { background: #eee; color: #333; border: none; padding: 10px 20px; border-radius: 8px; cursor: pointer; font-size: 14px; }
.btn-logout { background: #ff4d4d; color: white; border: none; padding: 8px 16px; border-radius: 8px; cursor: pointer; }

/* NAVBAR */
.navbar { background: white; padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
.navbar h2 { color: #667eea; }
.nav-right { display: flex; align-items: center; gap: 16px; }
.back-link { color: #667eea; }

/* DASHBOARD */
.dashboard-container { max-width: 1100px; margin: 30px auto; padding: 0 20px; }
.dashboard-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.dashboard-header .btn-primary { width: auto; }
.projects-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
.project-card { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); cursor: pointer; transition: transform 0.2s; border-left: 4px solid #667eea; }
.project-card:hover { transform: translateY(-4px); }
.project-card h3 { margin-bottom: 8px; color: #333; }
.project-card p { color: #888; font-size: 13px; }
.delete-btn { float: right; background: none; border: none; color: #ff4d4d; cursor: pointer; font-size: 18px; }

/* MODAL */
.modal { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; justify-content: center; align-items: center; z-index: 100; }
.modal-box { background: white; padding: 30px; border-radius: 16px; width: 420px; }
.modal-box h3 { margin-bottom: 16px; }
.modal-box input, .modal-box textarea { width: 100%; padding: 10px; margin-bottom: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; }
.modal-box textarea { height: 80px; resize: none; }
.modal-btns { display: flex; gap: 10px; }
.modal-btns .btn-primary { flex: 1; }

/* KANBAN */
.board-container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
.board-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
.board-header .btn-primary { width: auto; }
.kanban-board { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
.kanban-col { background: #f8f9fa; border-radius: 12px; padding: 16px; min-height: 400px; }
.kanban-col h4 { margin-bottom: 14px; font-size: 15px; padding-bottom: 10px; border-bottom: 2px solid #e0e0e0; }
.task-card { background: white; border-radius: 10px; padding: 14px; margin-bottom: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.07); }
.task-card h5 { margin-bottom: 6px; font-size: 14px; }
.task-card p { font-size: 12px; color: #888; margin-bottom: 10px; }
.task-actions { display: flex; gap: 6px; flex-wrap: wrap; }
.task-actions button { font-size: 11px; padding: 4px 8px; border: none; border-radius: 6px; cursor: pointer; }
.btn-move { background: #e8f4fd; color: #2196f3; }
.btn-comment { background: #e8f8e8; color: #4caf50; }
.btn-delete { background: #fdecea; color: #f44336; }

/* COMMENTS */
.comments-list { max-height: 200px; overflow-y: auto; margin-bottom: 12px; }
.comment-item { background: #f5f5f5; padding: 10px; border-radius: 8px; margin-bottom: 8px; font-size: 13px; }
.comment-item strong { color: #667eea; }
.comment-input { display: flex; gap: 8px; }
.comment-input input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 8px; }
.comment-input .btn-primary { width: auto; }

/* NOTIFICATIONS */
.notif-wrapper { position: relative; }
.notif-btn { background: none; border: none; font-size: 20px; cursor: pointer; position: relative; }
.badge { background: #ff4d4d; color: white; border-radius: 50%; font-size: 10px; padding: 2px 5px; position: absolute; top: -6px; right: -6px; }
.notif-dropdown { position: absolute; right: 0; top: 36px; background: white; border-radius: 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.15); width: 260px; z-index: 50; max-height: 300px; overflow-y: auto; }
.notif-item { padding: 12px 16px; font-size: 13px; border-bottom: 1px solid #f0f0f0; }
'@ | Set-Content frontend/css/style.css

# ========== frontend/js/auth.js ==========
@'
const API = "http://localhost:5000/api";

function showTab(tab) {
  document.getElementById("login").classList.add("hidden");
  document.getElementById("register").classList.add("hidden");
  document.getElementById(tab).classList.remove("hidden");
  document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
  event.target.classList.add("active");
}

async function login() {
  const email = document.getElementById("loginEmail").value;
  const password = document.getElementById("loginPassword").value;
  const res = await fetch(`${API}/auth/login`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password })
  });
  const data = await res.json();
  if (data.token) {
    localStorage.setItem("token", data.token);
    localStorage.setItem("user", JSON.stringify(data.user));
    window.location.href = "dashboard.html";
  } else {
    document.getElementById("authMsg").textContent = data.msg || "Login failed";
  }
}

async function register() {
  const name = document.getElementById("regName").value;
  const email = document.getElementById("regEmail").value;
  const password = document.getElementById("regPassword").value;
  const res = await fetch(`${API}/auth/register`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, email, password })
  });
  const data = await res.json();
  if (data.token) {
    localStorage.setItem("token", data.token);
    localStorage.setItem("user", JSON.stringify(data.user));
    window.location.href = "dashboard.html";
  } else {
    document.getElementById("authMsg").textContent = data.msg || "Registration failed";
  }
}

if (localStorage.getItem("token")) window.location.href = "dashboard.html";
'@ | Set-Content frontend/js/auth.js

# ========== frontend/js/dashboard.js ==========
@'
const API = "http://localhost:5000/api";
const token = localStorage.getItem("token");
const user = JSON.parse(localStorage.getItem("user") || "{}");
const socket = io("http://localhost:5000");
let notifications = [];

if (!token) window.location.href = "index.html";
document.getElementById("userName").textContent = "👤 " + (user.name || "");

function logout() { localStorage.clear(); window.location.href = "index.html"; }

async function loadProjects() {
  const res = await fetch(`${API}/projects`, { headers: { Authorization: `Bearer ${token}` } });
  const projects = await res.json();
  const grid = document.getElementById("projectsList");
  grid.innerHTML = "";
  if (projects.length === 0) {
    grid.innerHTML = '<p style="color:#888;grid-column:1/-1">No projects yet. Create one!</p>';
    return;
  }
  projects.forEach(p => {
    const card = document.createElement("div");
    card.className = "project-card";
    card.innerHTML = `
      <button class="delete-btn" onclick="deleteProject('${p._id}', event)">🗑</button>
      <h3>${p.name}</h3>
      <p>${p.description || "No description"}</p>
      <p style="margin-top:8px;font-size:12px;color:#aaa">👤 ${p.owner?.name || "Unknown"}</p>`;
    card.onclick = () => { localStorage.setItem("currentProject", JSON.stringify(p)); window.location.href = "project.html"; };
    grid.appendChild(card);
  });
}

async function createProject() {
  const name = document.getElementById("projectName").value;
  const description = document.getElementById("projectDesc").value;
  if (!name) return alert("Project name required!");
  await fetch(`${API}/projects`, {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ name, description })
  });
  closeModal();
  loadProjects();
}

async function deleteProject(id, e) {
  e.stopPropagation();
  if (!confirm("Delete this project?")) return;
  await fetch(`${API}/projects/${id}`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
  loadProjects();
}

function openModal() { document.getElementById("modal").classList.remove("hidden"); }
function closeModal() { document.getElementById("modal").classList.add("hidden"); document.getElementById("projectName").value = ""; document.getElementById("projectDesc").value = ""; }

function toggleNotifications() { document.getElementById("notifDropdown").classList.toggle("hidden"); }

socket.on("notification", (data) => {
  notifications.unshift(data);
  const count = document.getElementById("notifCount");
  count.classList.remove("hidden");
  count.textContent = notifications.length;
  const dropdown = document.getElementById("notifDropdown");
  dropdown.innerHTML = notifications.map(n => `<div class="notif-item">🔔 ${n.message}</div>`).join("");
});

loadProjects();
'@ | Set-Content frontend/js/dashboard.js

# ========== frontend/js/project.js ==========
@'
const API = "http://localhost:5000/api";
const token = localStorage.getItem("token");
const user = JSON.parse(localStorage.getItem("user") || "{}");
const project = JSON.parse(localStorage.getItem("currentProject") || "{}");
const socket = io("http://localhost:5000");
let notifications = [];
let currentTaskId = null;

if (!token) window.location.href = "index.html";
if (!project._id) window.location.href = "dashboard.html";

document.getElementById("userName").textContent = "👤 " + (user.name || "");
document.getElementById("projectTitle").textContent = project.name;
socket.emit("joinProject", project._id);

function logout() { localStorage.clear(); window.location.href = "index.html"; }

async function loadTasks() {
  const res = await fetch(`${API}/tasks/${project._id}`, { headers: { Authorization: `Bearer ${token}` } });
  const tasks = await res.json();
  ["todo", "inprogress", "done"].forEach(s => document.getElementById(s).innerHTML = "");
  tasks.forEach(renderTask);
}

function renderTask(task) {
  const col = document.getElementById(task.status);
  if (!col) return;
  const card = document.createElement("div");
  card.className = "task-card";
  card.innerHTML = `
    <h5>${task.title}</h5>
    <p>${task.description || ""}</p>
    <p style="font-size:11px;color:#aaa">👤 ${task.assignedTo?.name || "Unassigned"}</p>
    <div class="task-actions">
      ${task.status !== "todo" ? `<button class="btn-move" onclick="moveTask('${task._id}', '${task.status}', -1)">◀ Back</button>` : ""}
      ${task.status !== "done" ? `<button class="btn-move" onclick="moveTask('${task._id}', '${task.status}', 1)">Next ▶</button>` : ""}
      <button class="btn-comment" onclick="openCommentModal('${task._id}')">💬 Comments</button>
      <button class="btn-delete" onclick="deleteTask('${task._id}')">🗑</button>
    </div>`;
  col.appendChild(card);
}

const statusOrder = ["todo", "inprogress", "done"];

async function moveTask(id, currentStatus, direction) {
  const idx = statusOrder.indexOf(currentStatus);
  const newStatus = statusOrder[idx + direction];
  if (!newStatus) return;
  const res = await fetch(`${API}/tasks/${id}`, {
    method: "PUT", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ status: newStatus })
  });
  const task = await res.json();
  socket.emit("taskUpdated", { projectId: project._id, task, message: `Task "${task.title}" moved to ${newStatus}` });
  loadTasks();
}

async function createTask() {
  const title = document.getElementById("taskTitle").value;
  const description = document.getElementById("taskDesc").value;
  if (!title) return alert("Task title required!");
  await fetch(`${API}/tasks`, {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ title, description, project: project._id })
  });
  socket.emit("notification", { projectId: project._id, message: `New task "${title}" created by ${user.name}` });
  closeTaskModal();
  loadTasks();
}

async function deleteTask(id) {
  if (!confirm("Delete this task?")) return;
  await fetch(`${API}/tasks/${id}`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
  loadTasks();
}

function openTaskModal() { document.getElementById("taskModal").classList.remove("hidden"); }
function closeTaskModal() { document.getElementById("taskModal").classList.add("hidden"); document.getElementById("taskTitle").value = ""; document.getElementById("taskDesc").value = ""; }

async function openCommentModal(taskId) {
  currentTaskId = taskId;
  document.getElementById("commentModal").classList.remove("hidden");
  const res = await fetch(`${API}/comments/${taskId}`, { headers: { Authorization: `Bearer ${token}` } });
  const comments = await res.json();
  const list = document.getElementById("commentsList");
  list.innerHTML = comments.length === 0 ? "<p style='color:#aaa;font-size:13px'>No comments yet</p>" :
    comments.map(c => `<div class="comment-item"><strong>${c.author?.name}</strong>: ${c.text}</div>`).join("");
}

async function addComment() {
  const text = document.getElementById("commentText").value;
  if (!text) return;
  const res = await fetch(`${API}/comments`, {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ text, task: currentTaskId, project: project._id })
  });
  const comment = await res.json();
  socket.emit("commentAdded", { projectId: project._id, comment, message: `${user.name} commented on a task` });
  document.getElementById("commentText").value = "";
  openCommentModal(currentTaskId);
}

function closeCommentModal() { document.getElementById("commentModal").classList.add("hidden"); currentTaskId = null; }

function toggleNotifications() { document.getElementById("notifDropdown").classList.toggle("hidden"); }

socket.on("taskUpdated", () => loadTasks());
socket.on("commentAdded", (data) => { if (currentTaskId === data.comment?.task) openCommentModal(currentTaskId); });
socket.on("notification", (data) => {
  if (data.message && !data.message.includes(user.name)) {
    notifications.unshift(data);
    const count = document.getElementById("notifCount");
    count.classList.remove("hidden");
    count.textContent = notifications.length;
    const dropdown = document.getElementById("notifDropdown");
    dropdown.innerHTML = notifications.map(n => `<div class="notif-item">🔔 ${n.message}</div>`).join("");
  }
});

loadTasks();
'@ | Set-Content frontend/js/project.js

Write-Host "All files created successfully!" -ForegroundColor Green
