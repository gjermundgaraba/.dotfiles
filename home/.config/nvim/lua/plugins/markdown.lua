local add = require "utils.pack"

add({
  {
    src = "https://github.com/3rd/image.nvim",
    version = "master",
  },
  {
    src = "https://github.com/HakonHarnes/img-clip.nvim",
    version = "main",
  },
})

require("image").setup {
  processor = "magick_cli",
  integrations = {
    markdown = {
      enabled = true,
      clear_in_insert_mode = false,
      download_remote_images = true,
      only_render_image_at_cursor = false,
    },
  },
}

require("img-clip").setup {
  default = {
    dir_path = "assets",
    prompt_for_file_name = false,
  },
  filetypes = {
    markdown = {
      template = "![$CURSOR]($FILE_PATH)",
      url_encode_path = true,
    },
  },
}
