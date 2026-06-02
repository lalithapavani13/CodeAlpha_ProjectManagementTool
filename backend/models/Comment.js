const mongoose = require("mongoose");
const CommentSchema = new mongoose.Schema({
  text: { type: String, required: true },
  task: { type: mongoose.Schema.Types.ObjectId, ref: "Task" },
  project: { type: mongoose.Schema.Types.ObjectId, ref: "Project" },
  author: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  createdAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model("Comment", CommentSchema);
