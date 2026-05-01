---
layout: default
title: Hummingbird Tutorial
description: A follow-along, cut-and-paste tutorial for Red Hat Project Hummingbird using Podman.
sectionid: home
---

# Hummingbird Tutorial

This is a hands-on tutorial for **Project Hummingbird** — Red Hat's
catalog of minimal, hardened, near-zero-CVE container images — built
around the Podman family of tools (Podman, Podman Compose, Podman
Desktop).

The tutorial is meant to be **read in order, with a terminal open
beside the page**. Every command is intended to be copied and pasted
directly. There is no separate lab environment to provision: your
Fedora 43 workstation or macOS laptop is the lab.

## Start here

If this is your first time:

1. Read the [outline]({{ site.baseurl }}/docs/00-outline/) to see the
   full progression and decide where to stop the first time through.
2. Work through the [prerequisites]({{ site.baseurl }}/docs/01-prerequisites/)
   to make sure your machine has the tools you'll need.
3. Continue with [What is Project Hummingbird]({{ site.baseurl }}/docs/02-introduction/)
   for the conceptual grounding before any commands.

If you already know what Hummingbird is and just want to start
running it, jump to [Pulling and inspecting your first image]({{ site.baseurl }}/docs/03-podman-basics/).

## Tutorial sections

{% assign tutorial_docs = site.docs | sort: "order" %}
<ol>
  {% for doc in tutorial_docs %}
    {% if doc.hidden != true %}
      <li>
        <a href="{{ doc.url | prepend: site.baseurl }}">{{ doc.title }}</a>
        {% if doc.description %} &mdash; {{ doc.description }}{% endif %}
      </li>
    {% endif %}
  {% endfor %}
</ol>

## Project status

This tutorial is under active development. See the
[reconciliation plan]({{ site.baseurl }}/plans/reconciliation-plan/)
for what is complete, what is in flight, and where contributions are
most useful.
