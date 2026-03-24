# Skills

In this folder there are claude skills to:
- Create vuejs pages and componetns by also having as help
- Port lua pages to new vuejs components/pages
- Update REST to use rest_utils.answer


# Required Plugins

Install plugins to improve the UI design and lua checks

in claude type `/plugin`, search and install

- **clangd-lsp** for c++ syntax check and AST navigation
- **lua-lsp** for lua syntax check and AST navigation
- **frontend-design** plugin to create custom UIs enjoyable and non AI visible
- Grepai to reduce token usage search: 
    - `/plugin marketplace add yoanbernabeu/grepai-skills`
    - `/plugin install grepai-complete@grepai-skills`

# How to use skills 
In order to use these skills: 
- **ntop-vue-scaffold** to create vuejs components or pages
- **ntop-lua-to-vue-porter** to port old lua pages to use vuejs
- **ntop-rest-endpoint-scaffolder** to improve rest APIs to return correct content, not HTML or text to render

in claude code, either tell it:
- **Implicit request** `I need to refactor lua page /lua/about.lua to vuejs` or `i need to port this lua page to a modern, UI pleasant interface made in vuejs /lua/about.lua, also check if the rest returns html and needs porting to a new rest, if the rest is not in the default rest path /lua/rest/v2  move it there` 
- **Explicit request**: start the chat with the skill name and then describe the task and lua page path to refactor: `/ntop-lua-to-vue-porter`