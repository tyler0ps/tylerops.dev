import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'TylerOps',
  description: 'Tyler\'s personal blog about DevOps, low-level Linux systems, and cloud platforms.',

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated timestamp
  lastUpdated: true,

  // Head metadata
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'TylerOps' }],
    ['meta', { property: 'og:title', content: 'TylerOps - DevOps & Cloud Platform Engineering' }],
    ['meta', { property: 'og:description', content: 'Tyler\'s personal blog about DevOps, low-level Linux systems, and cloud platforms.' }],
    ['meta', { property: 'og:url', content: 'https://tylerops.dev' }],
  ],

  // Theme configuration
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'TylerOps',

    // Navigation bar
    nav: [
      { text: 'Home', link: '/' },
      { text: 'About', link: '/about' },
      { text: 'Blog', link: '/blog/' },
      { text: 'Series', link: '/series/container-networking/' },
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
      '/series/': [
        {
          text: 'Container Networking',
          items: [
            { text: 'Overview', link: '/series/container-networking/' },
            { text: 'Part 1: Building Container Networks from Scratch', link: '/series/container-networking/container-networking-1' },
          ]
        }
      ],
      '/projects/': [
        {
          text: 'Projects',
          items: [
            { text: 'Overview', link: '/projects/' },
            {
              text: 'AWS Baseline',
              collapsed: false,
              items: [
                { text: 'Overview', link: '/projects/aws-baseline/' },
                { text: 'Static Website Hosting', link: '/projects/aws-baseline/static-website-hosting' },
                { text: 'EKS + Karpenter', link: '/projects/aws-baseline/eks-karpenter-setup' }
              ]
            },
            { text: 'Challenges', link: '/projects/challenges' },
          ]
        }
      ]
    },

    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/tyler0ps' },
      { icon: 'linkedin', link: 'https://linkedin.com/in/tylerops' },
    ],

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
