from os import listdir
from time import sleep
from os.path import join
from selenium import webdriver
from BeautifulSoup import BeautifulSoup

import re
import random
import urllib2
import plistlib
import subprocess


def isValidLink(link):
    if len(link) > 25:
        return False

    bad = [":", "#", ",_", "List", "disambiguation", "(", "Outline"]
    for badItem in bad:
        if badItem in link:
            return False

    return True


def validateArticles(articles):
    validArticles = []
    for article in set(articles):
        if isValidLink("/wiki/" + article):
            validArticles.append(article)
        else:
            print(article)
    return validArticles


def combineArticlesAtPath(path):
    articles = []
    files = [join(path, f) for f in listdir(path)]

    for file in files:
        if "DS_Store" not in file:
            articles += plistlib.readPlist(file)
    return set(articles)


def commonTitleWords(articles):
    words = {}
    for article in articles:
        for word in article[1:].replace("_", " ").split():
            if word in words:
                words[word] += 1
            else:
                words[word] = 1
    return words


def commonTitleWordsAsString(articles):
    words = commonTitleWords(articles)

    string = ""
    for k, v in sorted(words.items(), reverse=True, key=lambda x: x[1]):
        string += u'{0}: {1}'.format(k, v) + "\n"

    return string
    # path = "/Users/andrewfinke/Desktop/NewMaster2.txt"
    # text_file = open(path, "w")
    # text_file.write(string)
    # text_file.close()


def fetchRedirect(driver, article):
    link = "https://en.m.wikipedia.org/wiki" + article

    driver.get(link)

    sleep(0.4)

    split = driver.current_url.split("/")
    newArticle = "/" + split[len(split) - 1]

    if newArticle != article:
        print("REDIRECT: " + newArticle)
    else:
        print("NO REDIRECT")
    return newArticle


def preciseContains(articleToCheck, articles):
    for article in articles:
        if article.lower() == articleToCheck.lower():
            return True
    return False


def preciseRemoveAllDups(articles):
    print("preciseRemoveDups")
    newArticles = []
    for article in articles:
        if preciseContains(article, newArticles) == False:
            newArticles.append(article)
        else:
            print("DUP: " + article)
    return newArticles


def fullNetworkingTest(articles):
    driver = webdriver.Firefox()

    validArticles = []
    redirectArticles = []
    errorArticles = []

    def saveArticles():
        validPath = "/Users/andrewfinke/Desktop/FullTest/CValid.plist"
        plistlib.writePlist(sorted(validArticles), validPath)

        redirectPath = "/Users/andrewfinke/Desktop/FullTest/CRedirect.plist"
        plistlib.writePlist(sorted(redirectArticles), redirectPath)

        errorPath = "/Users/andrewfinke/Desktop/FullTest/CError.plist"
        plistlib.writePlist(sorted(errorArticles), errorPath)

    for article in articles:
        print(article)
        try:
            html_page = urllib2.urlopen(
                "https://en.m.wikipedia.org/wiki" + article)
            if "Redirected from" in str(BeautifulSoup(html_page)):
                print("POSSIBLE REDIRECT")
                redirectArticles.append(fetchRedirect(driver, article))
            else:
                print("VALID")
                validArticles.append(article)

        except urllib2.HTTPError as err:
            print("ERROR")
            errorArticles.append(article)

        if len(validArticles) % 10 == 0:
            saveArticles()
    saveArticles()
    driver.quit()


def randomArticles(articles):
    for x in range(0, 300):
        randomArticles = []
        while len(randomArticles) != 8:
            randomArticle = random.choice(articles)
            if randomArticle not in randomArticles:
                randomArticles.append(randomArticle)
        print("\n=========\n")
        for article in randomArticles:
            print(article[1:].replace("_", " "))

# '/Apple_Inc.'


def fetchPageLinks(pageName):
    html_page = urllib2.urlopen("https://en.m.wikipedia.org/wiki/" + pageName)
    soup = BeautifulSoup(html_page)
    validLinks = []
    for link in soup.findAll('a', attrs={'href': re.compile("/wiki/")}):
        href = link.get('href')
        if isValidLink(href[5:]):
            validLinks.append(href[5:])
        else:
            print("NOT VALID: " + href)
    return sorted(list(set(validLinks)), key=lambda s: s.lower())


def fetchPagesThatLinkTo(page):
    url = "https://en.m.wikipedia.org/w/index.php?title=Special:WhatLinksHere" + \
        page + "&namespace=0&limit=500&hidetrans=1"
    try:
        html_page = urllib2.urlopen(url)
        soup = str(BeautifulSoup(html_page))
        return soup.count('/wiki/')
    except urllib2.HTTPError as err:
        return 0


def isDisambiguationPage(page):
    url = "https://en.m.wikipedia.org/wiki" + page
    try:
        html_page = urllib2.urlopen(url)
        soup = str(BeautifulSoup(html_page))
        if " page lists articles associated with the title " in soup:
            return True
    except urllib2.HTTPError as err:
        return False
    return False


def fullDisambiguationTests(articles):
    print("fullDisambiguationTests")

    articlesDis = []
    progress = 0
    for article in articles:
        progress += 1
        print(str(progress) + " / " + str(len(articles)))
        if isDisambiguationPage(article):
            articlesDis.append(article)

    path = "/Users/andrewfinke/Desktop/FullTest/DisambiguationLinks.plist"
    plistlib.writePlist(articlesDis, path)


def fullPageLinkTests(articles):
    print("fullPageLinkTests")

    articles50 = {}
    articles100 = {}
    articles150 = {}
    articles250 = {}
    articles350 = {}
    articles500 = {}
    articlesAll = {}

    progress = 0
    for article in articles:
        progress += 1
        print(str(progress) + " / " + str(len(articles)))
        count = fetchPagesThatLinkTo(article)
        articlesAll[article] = count
        if count < 50:
            articles50[article] = count
        elif count < 100:
            articles100[article] = count
        elif count < 150:
            articles150[article] = count
        elif count < 250:
            articles250[article] = count
        elif count < 350:
            articles350[article] = count
        else:
            articles500[article] = count

    path = "/Users/andrewfinke/Desktop/FullTest/50Links.plist"
    plistlib.writePlist(articles50, path)

    path = "/Users/andrewfinke/Desktop/FullTest/100Links.plist"
    plistlib.writePlist(articles100, path)

    path = "/Users/andrewfinke/Desktop/FullTest/150Links.plist"
    plistlib.writePlist(articles150, path)

    path = "/Users/andrewfinke/Desktop/FullTest/250Links.plist"
    plistlib.writePlist(articles250, path)

    path = "/Users/andrewfinke/Desktop/FullTest/350Links.plist"
    plistlib.writePlist(articles350, path)

    path = "/Users/andrewfinke/Desktop/FullTest/500Links.plist"
    plistlib.writePlist(articles500, path)

    path = "/Users/andrewfinke/Desktop/FullTest/AllLinks.plist"
    plistlib.writePlist(articlesAll, path)


def removeArticles(articlesToRemove, articles):
    for article, value in articlesToRemove.iteritems():
        if value < 100:
            if article in articles:
                articles.remove(article)
        else:
            print(article)
    return articles


def isPersonArticle(article):
    html_page = urllib2.urlopen("https://en.m.wikipedia.org/wiki" + article)
    soup = BeautifulSoup(html_page)
    allrows = soup.findAll('th')
    userrows = [t for t in allrows if t.findAll(text=re.compile('Born'))]
    return len(userrows) > 0


if __name__ == "__main__":
    path = "/Users/andrewfinke/Desktop/NewMasterA.plist"
    new_articles = plistlib.readPlist(
        path) + plistlib.readPlist("/Users/andrewfinke/Desktop/WKRArticlesDataoo.plist")
    #
    # fullNetworkingTest(old_articles)

    # tpath = "/Users/andrewfinke/Desktop/NewMaster2.txt"
    # text_file = open(tpath, "w")
    # text_file.write(commonTitleWordsAsString(old_articles))
    # text_file.close()

    # paths = [
    #     "/Users/andrewfinke/Desktop/FullTest/AValid.plist",
    #     "/Users/andrewfinke/Desktop/FullTest/ARedirect.plist",
    #     "/Users/andrewfinke/Desktop/FullTest/BValid.plist",
    #     "/Users/andrewfinke/Desktop/FullTest/BRedirect.plist",
    #     "/Users/andrewfinke/Desktop/FullTest/CValid.plist",
    #     "/Users/andrewfinke/Desktop/FullTest/CRedirect.plist",
    # ]
    #
    # old_articles = []
    # for path in paths:
    #     old_articles += plistlib.readPlist(path)
    #
    # new_articles = []
    # for article in old_articles:
    #     if isValidLink("/wiki" + article):
    #         new_articles.append(article)
    #

    new_articles = preciseRemoveAllDups(new_articles)

    # # fullPageLinkTests(old_articles)
    # # new_articles = []
    # #
    # # for article in old_articles:
    # #     if "_in_" not in article and "_of_" not in article:
    # #         new_articles.append(article)
    # #     # if isPersonArticle(article):
    # #     #     print("Person: " + article)
    # #     # else:
    # #     #     new_articles.append(article)
    # #
    # # # updated_articles = removeArticles(old_articles, new_articles)
    # #
    # # # fullPageLinkTests(newArticles[5000:15000])
    # # # # print(articles)
    plistlib.writePlist(sorted(new_articles, key=lambda s: s.lower(
    )), "/Users/andrewfinke/Desktop/WKRArticlesData.plist")