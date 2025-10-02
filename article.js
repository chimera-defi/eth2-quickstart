// Ethereum Node Setup Blog - Article Page JavaScript

// Get article ID from URL parameters
function getArticleId() {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('id');
}

// Get article data by ID
function getArticleById(id) {
    if (typeof blogData !== 'undefined' && blogData.posts) {
        return blogData.posts.find(post => post.id === id);
    }
    return null;
}

// Get related articles
function getRelatedArticles(currentArticle, limit = 3) {
    if (typeof blogData !== 'undefined' && blogData.posts) {
        return blogData.posts
            .filter(post => 
                post.id !== currentArticle.id && 
                (post.category === currentArticle.category || 
                 post.tags.some(tag => currentArticle.tags.includes(tag)))
            )
            .slice(0, limit);
    }
    return [];
}

// Load article content
function loadArticle() {
    const articleId = getArticleId();
    
    if (!articleId) {
        showError('Article not found');
        return;
    }
    
    const article = getArticleById(articleId);
    
    if (!article) {
        showError('Article not found');
        return;
    }
    
    // Update page title and meta tags
    updatePageMeta(article);
    
    // Update article content
    updateArticleContent(article);
    
    // Load related articles
    loadRelatedArticles(article);
    
    // Update navigation
    updateArticleNavigation(article);
}

// Update page meta tags
function updatePageMeta(article) {
    // Update title
    document.title = `${article.title} - Ethereum Node Setup Blog`;
    
    // Update meta description
    const metaDescription = document.getElementById('article-description');
    if (metaDescription) {
        metaDescription.content = article.excerpt;
    }
    
    // Update Open Graph tags
    const ogTitle = document.getElementById('og-title');
    const ogDescription = document.getElementById('og-description');
    const ogUrl = document.getElementById('og-url');
    const ogImage = document.getElementById('og-image');
    
    if (ogTitle) ogTitle.content = article.title;
    if (ogDescription) ogDescription.content = article.excerpt;
    if (ogUrl) ogUrl.content = `${window.location.origin}/article.html?id=${article.id}`;
    if (ogImage) ogImage.content = `${window.location.origin}/images/articles/${article.id}.jpg`;
    
    // Update Twitter Card tags
    const twitterTitle = document.getElementById('twitter-title');
    const twitterDescription = document.getElementById('twitter-description');
    const twitterImage = document.getElementById('twitter-image');
    
    if (twitterTitle) twitterTitle.content = article.title;
    if (twitterDescription) twitterDescription.content = article.excerpt;
    if (twitterImage) twitterImage.content = `${window.location.origin}/images/articles/${article.id}.jpg`;
    
    // Update canonical URL
    const canonicalUrl = document.getElementById('canonical-url');
    if (canonicalUrl) {
        canonicalUrl.href = `${window.location.origin}/article.html?id=${article.id}`;
    }
    
    // Update structured data
    updateStructuredData(article);
}

// Update structured data
function updateStructuredData(article) {
    const structuredData = document.getElementById('structured-data');
    if (structuredData) {
        const data = {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": article.title,
            "description": article.excerpt,
            "author": {
                "@type": "Organization",
                "name": article.author
            },
            "publisher": {
                "@type": "Organization",
                "name": "Ethereum Node Setup Guide",
                "logo": {
                    "@type": "ImageObject",
                    "url": `${window.location.origin}/images/logo.png`
                }
            },
            "datePublished": article.date,
            "dateModified": article.date,
            "mainEntityOfPage": {
                "@type": "WebPage",
                "@id": `${window.location.origin}/article.html?id=${article.id}`
            },
            "keywords": article.tags.join(', ')
        };
        
        structuredData.textContent = JSON.stringify(data);
    }
}

// Update article content
function updateArticleContent(article) {
    // Update breadcrumb
    const breadcrumbTitle = document.getElementById('breadcrumb-title');
    if (breadcrumbTitle) {
        breadcrumbTitle.textContent = article.title;
    }
    
    // Update article meta
    const articleCategory = document.getElementById('article-category');
    const articleDate = document.getElementById('article-date');
    const articleReadTime = document.getElementById('article-read-time');
    
    if (articleCategory) articleCategory.textContent = article.category;
    if (articleDate) articleDate.textContent = formatDate(article.date);
    if (articleReadTime) articleReadTime.textContent = article.readTime;
    
    // Update article title
    const articleTitle = document.getElementById('article-main-title');
    if (articleTitle) {
        articleTitle.textContent = article.title;
    }
    
    // Update article body
    const articleBody = document.getElementById('article-body');
    if (articleBody) {
        articleBody.innerHTML = article.content;
    }
    
    // Update article tags
    const articleTagsContainer = document.getElementById('article-tags-container');
    if (articleTagsContainer) {
        articleTagsContainer.innerHTML = article.tags.map(tag => 
            `<a href="blog.html?tag=${tag}" class="tag">${tag}</a>`
        ).join('');
    }
}

// Load related articles
function loadRelatedArticles(article) {
    const relatedArticles = getRelatedArticles(article);
    const relatedGrid = document.getElementById('related-articles');
    
    if (relatedGrid) {
        if (relatedArticles.length === 0) {
            relatedGrid.innerHTML = '<p>No related articles found.</p>';
            return;
        }
        
        relatedGrid.innerHTML = relatedArticles.map(relatedArticle => `
            <article class="blog-card" onclick="navigateToArticle('${relatedArticle.id}')">
                <div class="blog-card-image">
                    ${getCategoryIcon(relatedArticle.category)}
                </div>
                <div class="blog-card-content">
                    <span class="blog-card-category">${relatedArticle.category}</span>
                    <h3 class="blog-card-title">${relatedArticle.title}</h3>
                    <p class="blog-card-excerpt">${relatedArticle.excerpt}</p>
                    <div class="blog-card-meta">
                        <span class="blog-card-date">
                            📅 ${formatDate(relatedArticle.date)}
                        </span>
                        <span class="blog-card-read-time">
                            ⏱️ ${relatedArticle.readTime}
                        </span>
                    </div>
                </div>
            </article>
        `).join('');
    }
}

// Update article navigation
function updateArticleNavigation(article) {
    if (typeof blogData !== 'undefined' && blogData.posts) {
        const currentIndex = blogData.posts.findIndex(post => post.id === article.id);
        
        // Previous article
        const prevArticle = currentIndex > 0 ? blogData.posts[currentIndex - 1] : null;
        const prevLink = document.getElementById('prev-article');
        if (prevLink) {
            if (prevArticle) {
                prevLink.href = `article.html?id=${prevArticle.id}`;
                prevLink.querySelector('.nav-text').textContent = prevArticle.title;
                prevLink.style.display = 'flex';
            } else {
                prevLink.style.display = 'none';
            }
        }
        
        // Next article
        const nextArticle = currentIndex < blogData.posts.length - 1 ? blogData.posts[currentIndex + 1] : null;
        const nextLink = document.getElementById('next-article');
        if (nextLink) {
            if (nextArticle) {
                nextLink.href = `article.html?id=${nextArticle.id}`;
                nextLink.querySelector('.nav-text').textContent = nextArticle.title;
                nextLink.style.display = 'flex';
            } else {
                nextLink.style.display = 'none';
            }
        }
    }
}

// Get category icon
function getCategoryIcon(category) {
    const icons = {
        'tutorial': '📚',
        'technical': '⚙️',
        'news': '📰',
        'client': '🔧'
    };
    return icons[category] || '📝';
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
}

// Navigate to article
function navigateToArticle(articleId) {
    window.location.href = `article.html?id=${articleId}`;
}

// Share article
function shareArticle() {
    const articleId = getArticleId();
    const article = getArticleById(articleId);
    
    if (!article) return;
    
    const shareData = {
        title: article.title,
        text: article.excerpt,
        url: window.location.href
    };
    
    if (navigator.share) {
        navigator.share(shareData);
    } else {
        // Fallback: copy to clipboard
        navigator.clipboard.writeText(window.location.href).then(() => {
            alert('Article link copied to clipboard!');
        });
    }
}

// Bookmark article
function bookmarkArticle() {
    const articleId = getArticleId();
    const article = getArticleById(articleId);
    
    if (!article) return;
    
    // Get existing bookmarks
    let bookmarks = JSON.parse(localStorage.getItem('ethereum-node-blog-bookmarks') || '[]');
    
    // Check if already bookmarked
    const isBookmarked = bookmarks.includes(articleId);
    
    if (isBookmarked) {
        // Remove bookmark
        bookmarks = bookmarks.filter(id => id !== articleId);
        alert('Article removed from bookmarks');
    } else {
        // Add bookmark
        bookmarks.push(articleId);
        alert('Article bookmarked!');
    }
    
    // Save bookmarks
    localStorage.setItem('ethereum-node-blog-bookmarks', JSON.stringify(bookmarks));
    
    // Update bookmark button
    updateBookmarkButton(articleId);
}

// Update bookmark button
function updateBookmarkButton(articleId) {
    const bookmarks = JSON.parse(localStorage.getItem('ethereum-node-blog-bookmarks') || '[]');
    const isBookmarked = bookmarks.includes(articleId);
    const bookmarkBtn = document.querySelector('.bookmark-btn');
    
    if (bookmarkBtn) {
        bookmarkBtn.textContent = isBookmarked ? 'Bookmarked' : 'Bookmark';
        bookmarkBtn.style.backgroundColor = isBookmarked ? 'var(--success-color)' : 'var(--bg-card)';
    }
}

// Show error message
function showError(message) {
    const articleBody = document.getElementById('article-body');
    if (articleBody) {
        articleBody.innerHTML = `
            <div class="error-message">
                <h2>Error</h2>
                <p>${message}</p>
                <a href="blog.html" class="btn">Back to Blog</a>
            </div>
        `;
    }
}

// Initialize article page
document.addEventListener('DOMContentLoaded', function() {
    loadArticle();
    
    // Update bookmark button state
    const articleId = getArticleId();
    if (articleId) {
        updateBookmarkButton(articleId);
    }
    
    // Setup mobile menu toggle
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');
    
    if (hamburger && navMenu) {
        hamburger.addEventListener('click', function() {
            navMenu.classList.toggle('active');
            hamburger.classList.toggle('active');
        });
    }
});

// Smooth scrolling for anchor links
document.addEventListener('click', function(e) {
    if (e.target.matches('a[href^="#"]')) {
        e.preventDefault();
        const target = document.querySelector(e.target.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth' });
        }
    }
});

// Reading progress indicator
function updateReadingProgress() {
    const article = document.querySelector('.article-body');
    if (!article) return;
    
    const articleTop = article.offsetTop;
    const articleHeight = article.offsetHeight;
    const windowHeight = window.innerHeight;
    const scrollTop = window.pageYOffset;
    
    const progress = Math.min(100, Math.max(0, (scrollTop - articleTop + windowHeight) / articleHeight * 100));
    
    // Create or update progress bar
    let progressBar = document.querySelector('.reading-progress');
    if (!progressBar) {
        progressBar = document.createElement('div');
        progressBar.className = 'reading-progress';
        progressBar.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: ${progress}%;
            height: 3px;
            background: linear-gradient(90deg, var(--accent-color), var(--text-accent));
            z-index: 1001;
            transition: width 0.3s ease;
        `;
        document.body.appendChild(progressBar);
    } else {
        progressBar.style.width = `${progress}%`;
    }
}

// Update reading progress on scroll
window.addEventListener('scroll', updateReadingProgress);

// Initialize reading progress
document.addEventListener('DOMContentLoaded', updateReadingProgress);