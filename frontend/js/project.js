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
  const assignedTo = document.getElementById("taskAssign").value;
  if (!title) return alert("Task title required!");
  await fetch(`${API}/tasks`, {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ title, description, project: project._id, assignedTo })
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
  if (data.message) {
    notifications.unshift(data);
    const count = document.getElementById("notifCount");
    count.classList.remove("hidden");
    count.textContent = notifications.length;
    const dropdown = document.getElementById("notifDropdown");
    dropdown.innerHTML = notifications.map(n => `<div class="notif-item">🔔 ${n.message}</div>`).join("");
  }
});
async function loadUsers() {
  const res = await fetch(`${API}/projects/${project._id}`, { 
    headers: { Authorization: `Bearer ${token}` } 
  });
  const proj = await res.json();
  const select = document.getElementById("taskAssign");
  proj.members.forEach(m => {
    const option = document.createElement("option");
    option.value = m._id;
    option.textContent = m.name;
    select.appendChild(option);
  });
}


async function loadUsers() {
  const res = await fetch(`${API}/projects/${project._id}`, { 
    headers: { Authorization: `Bearer ${token}` } 
  });
  const proj = await res.json();
  const select = document.getElementById("taskAssign");
  select.innerHTML = '<option value="">Assign to...</option>';
  proj.members.forEach(m => {
    const option = document.createElement("option");
    option.value = m._id;
    option.textContent = m.name;
    select.appendChild(option);
  });
}

loadUsers();
loadTasks();

