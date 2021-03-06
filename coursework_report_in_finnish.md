### Salt Miniprojekti Raportti

Testiympäristö:

* Salt-Master (3004.1): Debian 11 Bullseye @ Virtualbox 6.1 (Host OS: Windows 10 Home 21H2), AMD Ryzen 5 3600X
* Salt-Minion (3004,1): Windows 10 Home (21H2), Intel i5-6200U

Aloitin [päivittämällä](https://repo.saltproject.io/#debian) Masterin samaan versioon (3004.1) tuon Windows-minionin kanssa (, sillä toimiakseen Masterin on oltava joko sama tai uudempi versio kuin minionin. Asensin Salt-Minonin Windowsille, ja sen yhteydessä määrittelin Masterin ip:n. Testasin toimivuutta test.ping -komennolla ja yksinkertaisella helloworld -tilalla.

 Lisäksi asensin Masterille Saltin Windows-pakettivarastot (*salt-run winrepo.update_git_repos*) ja päivitin ne Minionille (*salt win_laptop pkg.refresh_db*).

![testit1](https://i.imgur.com/2jRJyhN.png)

Seuraavaksi lähdin muuttamaan Windowsin asetuksia Saltin reg.present -funktiota käyttäen. Saltin dokumentaatioita apuna käyttäen kirjoitin alla olevan tilan, minkä siis pitäisi kirjoittaa rekisteriin asetuksen arvo Deny, joka siis muuttaisi Windowsin käyttäjäasetuksista kohtaa "Allow apps to access your account info" off -asentoon Kun tilan ajaa se näyttäisi toimivan oikein, mutta kun kävin minionilla katsomassa, niin siellä ei rekisterissä tai sitä vastaavassa asetuksessa ollut mikään muuttunut. Ilmeisesti tämä johtuu siitä, että tilassa ei ollu määritelty oikeuksia oikein, Grant tai Deny -kohtiin ei kirjoiteta. Lisäsiin tilaan alla olevat rivit, joilla käyttäjälle vilppu sallittaisiin kaikki oikeudet, ja rekisteriin kirjoittamisen tulisi onnistua.

```
 1 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation':
 2    reg.present:
 3      - vname: Value
 4      - vdata: Deny
 5      - vtype: REG_SZ

```
```
 6     - win_owner: Administrators
 7     - win_perms:
 8         vilppu:
 9           perms: full_control
10           applies_to:
11             - this_key_only
12     - win_inheritance: True
13     - win_perms_reset: True
```
![regtest](https://i.imgur.com/Ou1Wl8M.png)

![errroror](https://i.imgur.com/zHdozOh.png)

Eli tosiaan, kun tätä tilaa missä oikeuksia oli muokattu koitti ajaa ruutuun lävähti aikamoinen lista punaista. Kun tuota erroria hieman googletteli löytyi siitä [bugiraportti](https://github.com/saltstack/salt/issues/61271) ja siihen myös [fixi](https://github.com/saltstack/salt/pull/61272). Latasin Githubista tuon bugfixin ja etsin minionilta tuon kansion (*"C:\Program Files\Salt Project\Salt\bin\Lib\site-packages\salt-3004.1-py3.8.egg\salt\utils\"*), minne tuo fixin sisältävä *win_dacl.py* kuuluu. Lisäsin ja korvasin tiedoston, käynnistin Minionin uudestaan (net stop & net start salt-minion) ja testasin uudestaan, mutta samaa erroria antoi. Päätin kokeilla uudestaan, siten että asennan Salt-Minionin uudestaan ja en käynnistä sitä suoraan asennuksen yhteydessä, vaan käyn ensiksi laittamassa tuon *win_dacl.py* -tiedoston paikoilleen. Tämäkään ei tuottanut tulosta, vaan samaa erroria vieläkin. Päätin vielä kerran kokeilla uudelleenasennusta, mutta tällä kertaa siten että korvaan koko utils -kansion sisältöineen tuolta SaltStackin Githubista ladatulla versiolla. Tämä Hail Mary -yrityskään ei yllättäen toiminut, vaan rikkoi koko Salt-Minionin.

![rikki](https://i.imgur.com/FIBS0PS.png)

En kuollaksenikaan saa tätä bugfixiä toimimaan, joten tuo Windows-asetusten hallinta rekisteriä muokaten Saltilla taitaa jäädä haaveeksi. Joko tässä on joku versiosta riippuvainen yhteensopivuusongelma, tai vaihtoehtoisesti ratkaisu on joku naurettavan yksinkertainen ja voi taas miettiä miten sitä ei tajunnut ottaa huomioon.

Tästä hieman lannistuneena päätin koittaa pakettien hallintaa Windowsilla, jotta olisi edes jotakin toimivaa ja esitettävää keskiviikkona. Tosiaan nuo Saltin Windows-pakettivarastot olin jo alku setupin yhteydessä asentanut Masterille, joten pakettien asennus Windowsille pitäisi toimia vain tuota pkg.installed -funktiota käyttäen. No tämä sentään onnistui, joten lisäsin listaan muutaman ohjelman (steam, firefox), johon määrittelin myös asetukset tuota file.managed -funktiota käyttäen. Lisäksi asentelin tuon chocolateyn kautta TeamSpeak3 -clientin.

```
 1 ohjelmat:
 2     pkg.installed:
 3       - pkgs:
 4           - chocolatey
 5           - git
```
```
 6           - steam
 7           - putty
 8           - wireshark
 9           - firefox_x64
10
11 ts3_choco:
12   chocolatey.installed:
13     - name: teamspeak
```

![pkg](https://i.imgur.com/hQTthAm.png)

![pkgs]()

Myöskin Windowsin palomuurin konffaaminen onnistuu Saltilla, joten päätin tehdä tilan, joka katsoo että palomuuri on käytössä kaikissa verkoissa ja lisäksi, että SSH:n  oletusportti on auki.

```
38 enable_all:
39   win_firewall.enabled:
40     - name: allprofiles
41
42 ssh_open:
43   win_firewall.add_rule:
44     - name: SSH (22)
45     - localport: 22
46     - protocol: tcp
```
![winfirewall](https://i.imgur.com/f0WjJdm.png)

Lopuksi ajatuksena oli poistaa Windowsin automaattisesti asentamia oletusohjelmia, koska nämä ohjelmat asentuvant Microsoft Storen kautta ei niitä ole valmiiksi Saltin tai Chocolateyn pakettivarastoissa, joten ainoa keino poistaa ne on käyttää PowerShell -komentoja (*Get-AppxPackage Name | Remove-AppxPackage*) Saltin cmd.run -funktiolla. Ongelma on vain siinä, että miten tehdä komennosta idempotentti. Ajattelin ensin käyttää käynnistä -valikon pikakuvakkeiden polkua ehtona (*onlyif: Test-Path*), mutta näillä oletusohjelmilla ei [valitettavasti](https://answers.microsoft.com/en-us/windows/forum/all/start-menu-shortcuts-for-windows-store-apps/b8626186-8917-48e8-ad7a-636bb71f4e0a) koko polkua ole olemassakaan. 

![esim1](https://i.imgur.com/Pwn6l49.png)

![esim2](https://i.imgur.com/OKpcCkC.png)

No seuraava idea oli mennä näiden ohjelmien asennuskansioon (*C:\Program Files\WindowsApps*) ja etsiä sieltä joku tiedosto mitä käyttää ehtona. No helpommin sanottu, kuin tehny sillä ensinäkin päästäkseen kyseiseen kansioon tarvitsee muokata rekisteriä saadakseen oikeudet muokata sitä, ja toisekseen sen sisältö on melkoista sekasotkua.

![esim3](https://i.imgur.com/1AK42an.png)

No seuraava idea oli monitoroida ohjelmien taustaprosesseja, mutta tässä on sellainen ongelma, että ainoastaan XboxApp:illa noista kaikista valmiiksi asennetuista ohjelmista on joku taustaprosessi käynnissä. Teoriassa kai nuo kaikkien ohjelmien poiston saisi sidottua tuohon yhteen prosessiin tekemällä yhden PowerShell -skriptin,joka poistaisi kaikki oletus ohjelmat ja ajettaisiin, jos tuo prosessi olisi päällä, mutta en tiedä kuinka tarkoituksenmukaista tai järkevää se olisi. No kokeilin kuitenkin alla olevaa tilaa, minkä pitäisi poistaa XboxApp, jos tuo prosessi löytyy. Tila pseudo-toimii, eli näyttää että se ajettaisiin ja tekisi muutoksia, mutta todellisuudessa minionilla ei tapahdu mitään, eikä se myöskään ole idempotentti. Ajan ja hermojen rajallisuuden vuoksi en yritä saada sitä toimimaan.

```
 1 'Get-AppxPackage *xboxapp* | Remove-AppxPackage':
 2   cmd.run:
 3     - shell: powershell
 4     - onlyif: (Get-Process XboxAppServices)
```

![asxddasadas](https://i.imgur.com/jMR9AXj.png)



Lähteet:

*  https://repo.saltproject.io/#debian
*  https://docs.saltproject.io/en/latest/topics/about_salt_project.html
*  https://docs.microsoft.com/en-us/powershell/scripting/samples/managing-processes-with-process-cmdlets?view=powershell-7.2
* https://github.com/saltstack/salt/issues/61
* https://github.com/saltstack/salt/pull/61272
