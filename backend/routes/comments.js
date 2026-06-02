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
