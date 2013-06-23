#= require vendor
#= require lib
#= require api
#= require commands
#= require systems
#= require services
#= require files
#= require setup

$ ->
  session = new Session()
  nav = new NavBar(session)
  nav.draw()
  buttons =
    Systems:  ICONS.commandline
    Services: ICONS.magic
    Files:    ICONS.page2
    Setup:    ICONS.gear2
    Logout:   ICONS.power
  nav.addButton(label, icon) for label, icon of buttons

  pages =
    '/systems':  new SystemsPage(session)
    '/services': new ServicesPage(session)
    '/files':    new FilesPage(session)
    '/setup':    new SetupPage(session)
    '/logout':   new LogoutPage(session)
    'default':   new LoginPage(session, '/systems/')
  new Router(pages).draw()
  nav.select $('#nav-link-systems').parent()
