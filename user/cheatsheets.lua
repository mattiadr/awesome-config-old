local cheatsheets = {}

cheatsheets.git = {
	name = "git",
	{ group = "Alias",
		{ cmd = "gs",  description = "git status"    },
		{ cmd = "gaa", description = "git add -all"  },
		{ cmd = "gcm", description = "git commit -m" },
		{ cmd = "gp",  description = "git push"      },
		{ cmd = "gl",  description = "git pull"      },
	},
	{ group = "Misc",
		{ cmd = "git reset HEAD [file]", description = "remove file from staging area" },
	},
}

return cheatsheets