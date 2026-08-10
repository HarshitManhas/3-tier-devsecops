'use strict';
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getAllUsers, addUser, updateUser, deleteUser } = require('../controllers/userController');

router.use(auth); // All user routes require authentication

router.get('/',       getAllUsers);
router.post('/',      addUser);
router.put('/:id',   updateUser);
router.delete('/:id', deleteUser);

module.exports = router;
