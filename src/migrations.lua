local schema = require("lapis.db.schema")
local types = schema.types

return {
  [1] = function()
    schema.create_table("user", {
      { "id", types.text },
      { "username", types.text },
      { "email", types.text },
      { "passwordHash", types.text },
      { "active", types.boolean},
    })
  end,
  [1437336576] = function()
    schema.create_table("tag", {
      { "id", types.text },
      { "name", types.text },
      { "title", types.text },
      { "description", types.text }
    })
    schema.create_table("post", {
      { "id", types.text },
      { "title", types.text },
      { "link", types.text },
      { "text", types.text },
    })
  end,
  [1437338350] = function()
    schema.create_table("posttags", {
      { "postID", types.text },
      { "tagID", types.text },
      { "up", types.integer },
      { "down", types.integer },
      { "date", types.integer }
    })
  end
}
