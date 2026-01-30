import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'DevOps Accelerator',
  description: 'Working DevOps setups and reference implementations.',

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated timestamp
  lastUpdated: true,

  // Head metadata
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'DevOps Accelerator' }],
    ['meta', { property: 'og:title', content: 'DevOps Accelerator - Working DevOps setups' }],
    ['meta', { property: 'og:description', content: 'Working DevOps setups and reference implementations.' }],
    ['meta', { property: 'og:url', content: 'https://tylerops.dev' }],
  ],

  // Theme configuration
  themeConfig: {
    siteTitle: 'DevOps Accelerator',

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
            { text: 'EKS + Karpenter', link: '/blog/posts/eks-karpenter-setup' },
          ]
        }
      ],
      '/projects/': [
        {
          text: 'Projects',
          items: [
            { text: 'Overview', link: '/projects/' },
            { text: 'DevOps Materials', link: '/projects/devops-materials' },
            { text: 'DevOps Practices', link: '/projects/devops-practices' },
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
    hostname: 'https://tylerops.dev'
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
