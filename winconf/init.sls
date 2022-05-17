ohjelmat:
    pkg.installed:
      - pkgs:
          - chocolatey
          - git
          - steam
          - putty
          - wireshark
          - firefox_x64

ts3_choco:
  chocolatey.installed:
    - name: teamspeak

firefox_settings:
  file.managed:
    - makedirs: True
    - names:
        - C:\Users\vilppu\AppData\Roaming\Mozilla\Firefox\Profiles\3vbuzy1l.default-release\prefs.js:
          - source: salt://winconf/firefox/prefs.js
        - C:\Users\vilppu\AppData\Roaming\Mozilla\Firefox\Profiles\3vbuzy1l.default-release\addons.json:
          - source: salt://winconf/firefox/addons.json

C:\Users\vilppu\AppData\Roaming\TS3Client\settings.db:
  file.managed:
     - source: salt://winconf/ts3/settings.db
     - makedirs: True        
  
steam_userconf:
  file.managed:
    - makedirs: True
    - names:
      - C:\Program Files (x86)\Steam\userdata\40373206\config\localconfig.vdf:
        - source: salt://winconf/steam/localconfig.vdf
      - C:\Program Files (x86)\Steam\userdata\40373206\730\local\cfg\autoexec.cfg:
        - source: salt://winconf/steam/autoexec.cfg

enable_all:
  win_firewall.enabled:
    - name: allprofiles

ssh_open:
  win_firewall.add_rule:
    - name: SSH (22)
    - localport: 22
    - protocol: tcp
    - action: allow
