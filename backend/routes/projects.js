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

router.put("/:id/addmember", auth, async (req, res) => {
  try {
    const { email } = req.body;
    const user = await require("../models/User").findOne({ email });
    if (!user) return res.status(404).json({ msg: "User not found" });
    const project = await Project.findById(req.params.id);
    if (project.members.includes(user._id)) 
      return res.status(400).json({ msg: "Already a member" });
    project.members.push(user._id);
    await project.save();
    res.json({ msg: "Member added" });
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});
router.get("/:id", auth, async (req, res) => {
  try {
    const project = await Project.findById(req.params.id)
      .populate("members", "name email")
      .populate("owner", "name email");
    res.json(project);
  } catch (err) {
    res.status(500).json({ msg: "Server error" });
  }
});

module.exports = router;



