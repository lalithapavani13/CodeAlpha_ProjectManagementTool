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
  <p style="margin-top:8px;font-size:12px;color:#aaa">👤 ${p.owner?.name || "Unknown"}</p>
  <button class="btn-add-member" onclick="addMember('${p._id}', event)">+ Add Member</button>`;
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

async function addMember(projectId, e) {
  e.stopPropagation();
  const email = prompt("Enter member's email address:");
  if (!email) return;
  const res = await fetch(`${API}/projects/${projectId}/addmember`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ email })
  });
  const data = await res.json();
  if (data.msg === "Member added") {
    alert("Member added successfully! ✅");
    loadProjects();
  } else {
    alert(data.msg || "Error adding member");
  }
}
loadProjects();

