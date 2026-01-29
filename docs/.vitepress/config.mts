import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'OceanCloud',
  description: 'Senior DevOps Engineer - Cloud Infrastructure & Platform Engineering',

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated timestamp
  lastUpdated: true,

  // Head metadata
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'OceanCloud' }],
    ['meta', { property: 'og:title', content: 'Tyler - Senior DevOps Engineer' }],
    ['meta', { property: 'og:description', content: 'Cloud Infrastructure & Platform Engineering' }],
    ['meta', { property: 'og:url', content: 'https://oceancloud.click' }],
  ],

  // Theme configuration
  themeConfig: {
    siteTitle: 'OceanCloud',

    // Navigation bar
    nav: [
      { text: 'Home', link: '/' },
      { text: 'About', link: '/about' },
      { text: 'Blog', link: '/blog/' },
      { text: 'Projects', link: '/projects/' },
    ],

    // Sidebar configuration
    sidebar: {
      '/blog/': [
        {
          text: 'Blog Posts',
          items: [
            { text: 'All Posts', link: '/blog/' },
          ]
        }
      ],
      '/projects/': [
        {
          text: 'Projects',
          items: [
            { text: 'Overview', link: '/projects/' },
          ]
        }
      ]
    },

    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/tyler0ps' },
      { icon: 'linkedin', link: 'https://linkedin.com/in/tylerops' },
    ],

    // Footer
    footer: {
      message: 'Built with VitePress',
      copyright: 'Copyright 2025 tylerops'
    },

    // Search
    search: {
      provider: 'local'
    },

    // Edit link
    editLink: {
      pattern: 'https://github.com/tyler0ps/tylerops.dev/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    }
  },

  // Sitemap generation
  sitemap: {
    hostname: 'https://oceancloud.click'
  },

  // Markdown configuration
  markdown: {
    lineNumbers: true,
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    }
  }
})
