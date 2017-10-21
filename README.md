# Intro

PrestaScan is a fork of WPScan for PrestaShop.
It's under development and not finished at all.

Actually it only detects PrestaShop version and do other useless stuff.
Building a full database of vulnerabilities is time consuming especially because there is no website reporting it.  

If you want to help, let's talk :) !

# INSTALL

As it's a fork of WPScan, PrestaScan needs Ruby >= 2.1.9 and RubyGems.

Just clone this repo, install needed gems and you're good to go.
```
git clone http://too_lazy_to_get_the_url PrestaScan
bundle install

```
## Start PrestaScan

```
ruby prestascan.rb --url https://prestashop_website_url

```
In most of the case do not follow the redirection.


# KNOWN ISSUES

  PrestaShop is not detected when the base url has a 301 redirect. 
        Just use the -f option
