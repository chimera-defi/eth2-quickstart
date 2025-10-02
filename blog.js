// Ethereum Node Setup Blog - JavaScript for Blog Functionality

// Blog data structure
const blogData = {
    posts: [
        {
            id: 'ethereum-client-diversity-guide',
            title: 'Complete Guide to Ethereum Client Diversity',
            excerpt: 'Learn why client diversity matters for Ethereum network security and how to choose the right combination of execution and consensus clients for your node.',
            content: `
                <h2>Why Client Diversity Matters</h2>
                <p>Ethereum's security model relies on having multiple independent client implementations. When too many validators use the same client, it creates a single point of failure that could potentially compromise the network.</p>
                
                <h3>Current Client Landscape</h3>
                <p>As of 2024, Ethereum supports multiple execution and consensus clients:</p>
                
                <h4>Execution Clients (ETH1)</h4>
                <ul>
                    <li><strong>Geth</strong> - The original Go implementation, most stable and widely used</li>
                    <li><strong>Erigon</strong> - Re-architected for efficiency and faster sync times</li>
                    <li><strong>Reth</strong> - Modern Rust implementation with modular architecture</li>
                    <li><strong>Nethermind</strong> - Enterprise-focused .NET client with advanced features</li>
                    <li><strong>Besu</strong> - Apache 2.0 licensed Java client, great for private networks</li>
                </ul>
                
                <h4>Consensus Clients (ETH2)</h4>
                <ul>
                    <li><strong>Prysm</strong> - Well-documented Go client, great for beginners</li>
                    <li><strong>Lighthouse</strong> - Security-focused Rust client with excellent performance</li>
                    <li><strong>Teku</strong> - Java client with enterprise features and monitoring</li>
                    <li><strong>Nimbus</strong> - Lightweight Nim client, perfect for resource-constrained systems</li>
                    <li><strong>Lodestar</strong> - TypeScript client, developer-friendly</li>
                    <li><strong>Grandine</strong> - High-performance Rust client with cutting-edge optimizations</li>
                </ul>
                
                <h3>Choosing Your Client Combination</h3>
                <p>When selecting clients, consider:</p>
                <ul>
                    <li><strong>Resource Requirements</strong> - Some clients are more resource-intensive than others</li>
                    <li><strong>Sync Speed</strong> - Different clients have different sync strategies</li>
                    <li><strong>Community Support</strong> - Larger communities mean more documentation and help</li>
                    <li><strong>Client Diversity</strong> - Choose minority clients to improve network resilience</li>
                </ul>
                
                <h3>Recommended Combinations</h3>
                <p><strong>For Beginners:</strong> Geth + Prysm (most documentation and support)</p>
                <p><strong>For Performance:</strong> Erigon/Reth + Lighthouse (optimized for speed)</p>
                <p><strong>For Low Resources:</strong> Geth + Nimbus (proven on various hardware)</p>
                <p><strong>For Enterprise:</strong> Nethermind/Besu + Teku (enterprise features)</p>
                
                <h3>Getting Started</h3>
                <p>Use our interactive client selection tool to get personalized recommendations:</p>
                <pre><code>./select_clients.sh</code></pre>
                
                <p>This script will analyze your system requirements and suggest the best client combination for your specific use case.</p>
            `,
            category: 'tutorial',
            tags: ['ethereum', 'client-diversity', 'consensus', 'execution', 'security'],
            date: '2024-01-15',
            readTime: '8 min read',
            author: 'Ethereum Node Setup Team',
            featured: true
        },
        {
            id: 'prysm-checkpoint-sync-setup',
            title: 'Setting Up Prysm Checkpoint Sync for Faster Initial Sync',
            excerpt: 'Learn how to use checkpoint sync to dramatically reduce your Prysm beacon node sync time from days to minutes.',
            content: `
                <h2>What is Checkpoint Sync?</h2>
                <p>Checkpoint sync is a feature that allows you to start your beacon node from a recent checkpoint instead of syncing from genesis. This can reduce sync time from days to minutes.</p>
                
                <h3>How Checkpoint Sync Works</h3>
                <p>Instead of downloading and verifying every block from genesis, checkpoint sync:</p>
                <ol>
                    <li>Downloads a recent checkpoint (block and state)</li>
                    <li>Verifies the checkpoint against the network</li>
                    <li>Syncs forward from the checkpoint to the current head</li>
                </ol>
                
                <h3>Setting Up Checkpoint Sync</h3>
                <p>First, stop your existing beacon chain service:</p>
                <pre><code>sudo systemctl stop cl</code></pre>
                
                <p>Then run Prysm with checkpoint sync enabled:</p>
                <pre><code>$(echo $HOME)/prysm/prysm.sh cl \\
    --checkpoint-block=$PWD/prysm/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz \\
    --checkpoint-state=$PWD/prysm/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz \\
    --genesis-state=$PWD/prysm/genesis.ssz \\
    --config-file=$PWD/prysm/prysm_beacon_conf.yaml \\
    --p2p-host-ip=$(curl -s v4.ident.me)</code></pre>
                
                <h3>Verifying Checkpoint Sync</h3>
                <p>Monitor the sync progress:</p>
                <pre><code>journalctl -fu cl</code></pre>
                
                <p>Look for messages indicating successful checkpoint verification and forward sync progress.</p>
                
                <h3>Restarting Services</h3>
                <p>Once checkpoint sync is complete, restart your services:</p>
                <pre><code>sudo systemctl restart cl
sudo systemctl restart validator</code></pre>
                
                <h3>Troubleshooting</h3>
                <p>If checkpoint sync fails:</p>
                <ul>
                    <li>Check that the checkpoint files are valid and recent</li>
                    <li>Ensure your system has enough disk space</li>
                    <li>Verify network connectivity</li>
                    <li>Check Prysm logs for specific error messages</li>
                </ul>
            `,
            category: 'technical',
            tags: ['prysm', 'checkpoint-sync', 'beacon-node', 'sync', 'optimization'],
            date: '2024-01-12',
            readTime: '6 min read',
            author: 'Ethereum Node Setup Team',
            featured: true
        },
        {
            id: 'geth-optimization-guide',
            title: 'Geth Performance Optimization Guide',
            excerpt: 'Optimize your Geth execution client for maximum performance and efficiency with these proven configuration tweaks.',
            content: `
                <h2>Geth Configuration Optimization</h2>
                <p>Geth is the most widely used Ethereum execution client. With proper configuration, you can significantly improve its performance and reduce resource usage.</p>
                
                <h3>Memory Configuration</h3>
                <p>Geth's memory usage can be optimized through several parameters:</p>
                
                <h4>Cache Settings</h4>
                <pre><code>--cache 4096          # 4GB cache (adjust based on available RAM)
--cache.database 1024  # 1GB database cache
--cache.trie 2048      # 2GB trie cache</code></pre>
                
                <h3>Network Configuration</h3>
                <p>Optimize network settings for better peer connections:</p>
                <pre><code>--maxpeers 50         # Maximum number of peers
--maxpendpeers 10     # Maximum pending connections
--nat extip:$(curl -s v4.ident.me)  # External IP for better connectivity</code></pre>
                
                <h3>Database Optimization</h3>
                <p>Configure database settings for better performance:</p>
                <pre><code>--db.engine leveldb   # Use LevelDB (default, most stable)
--db.ancient /path/to/ancient  # Store old data separately
--db.gc 1000000       # Garbage collection threshold</code></pre>
                
                <h3>RPC Configuration</h3>
                <p>Secure and optimize your RPC endpoint:</p>
                <pre><code>--http
--http.addr 0.0.0.0
--http.port 8545
--http.api eth,net,web3,personal,admin
--http.corsdomain "*"
--ws
--ws.addr 0.0.0.0
--ws.port 8546
--ws.api eth,net,web3,personal,admin</code></pre>
                
                <h3>Performance Monitoring</h3>
                <p>Monitor Geth performance with these commands:</p>
                <pre><code># Check sync status
geth attach --exec "eth.syncing"

# Monitor memory usage
ps aux | grep geth

# Check database size
du -sh ~/.ethereum/geth/chaindata/</code></pre>
                
                <h3>System Requirements</h3>
                <p>For optimal Geth performance:</p>
                <ul>
                    <li><strong>RAM:</strong> 16GB+ (32GB recommended)</li>
                    <li><strong>Storage:</strong> Fast SSD/NVMe (2TB+ for full node)</li>
                    <li><strong>CPU:</strong> 4+ cores (8+ recommended)</li>
                    <li><strong>Network:</strong> Stable broadband connection</li>
                </ul>
            `,
            category: 'technical',
            tags: ['geth', 'optimization', 'performance', 'execution-client', 'configuration'],
            date: '2024-01-10',
            readTime: '7 min read',
            author: 'Ethereum Node Setup Team',
            featured: false
        },
        {
            id: 'ethereum-staking-security-best-practices',
            title: 'Ethereum Staking Security Best Practices',
            excerpt: 'Essential security practices for running Ethereum validators safely and protecting your staked ETH.',
            content: `
                <h2>Validator Security Fundamentals</h2>
                <p>Running an Ethereum validator involves significant financial responsibility. Follow these security best practices to protect your staked ETH and maintain network participation.</p>
                
                <h3>Key Management</h3>
                <p>Your validator keys are the most critical security component:</p>
                
                <h4>Secure Key Generation</h4>
                <ul>
                    <li>Generate keys on an air-gapped computer</li>
                    <li>Use strong, unique passwords for keystores</li>
                    <li>Store backup phrases in multiple secure locations</li>
                    <li>Never share private keys or seed phrases</li>
                </ul>
                
                <h4>Key Storage</h4>
                <ul>
                    <li>Use hardware wallets when possible</li>
                    <li>Encrypt all key files at rest</li>
                    <li>Store backups in geographically separate locations</li>
                    <li>Regularly test key recovery procedures</li>
                </ul>
                
                <h3>Server Security</h3>
                <p>Protect your validator server with these measures:</p>
                
                <h4>Access Control</h4>
                <ul>
                    <li>Disable root login after initial setup</li>
                    <li>Use SSH key authentication only</li>
                    <li>Implement fail2ban for brute force protection</li>
                    <li>Regularly update system packages</li>
                </ul>
                
                <h4>Network Security</h4>
                <ul>
                    <li>Configure firewall rules properly</li>
                    <li>Use VPN for remote access</li>
                    <li>Monitor network traffic for anomalies</li>
                    <li>Implement intrusion detection systems</li>
                </ul>
                
                <h3>Monitoring and Alerting</h3>
                <p>Set up comprehensive monitoring for your validator:</p>
                
                <h4>System Monitoring</h4>
                <ul>
                    <li>Monitor CPU, RAM, and disk usage</li>
                    <li>Track network connectivity and latency</li>
                    <li>Monitor service status and uptime</li>
                    <li>Set up automated alerts for issues</li>
                </ul>
                
                <h4>Validator Monitoring</h4>
                <ul>
                    <li>Track validator performance metrics</li>
                    <li>Monitor for missed attestations</li>
                    <li>Watch for slashing conditions</li>
                    <li>Track reward accumulation</li>
                </ul>
                
                <h3>Operational Security</h3>
                <p>Maintain security through proper operational practices:</p>
                
                <h4>Regular Maintenance</h4>
                <ul>
                    <li>Keep all software updated</li>
                    <li>Regularly backup configuration files</li>
                    <li>Test disaster recovery procedures</li>
                    <li>Review and audit access logs</li>
                </ul>
                
                <h4>Incident Response</h4>
                <ul>
                    <li>Have a plan for validator downtime</li>
                    <li>Know how to quickly stop a compromised validator</li>
                    <li>Maintain contact information for support</li>
                    <li>Document all procedures and contacts</li>
                </ul>
                
                <h3>Common Security Mistakes</h3>
                <p>Avoid these common security pitfalls:</p>
                <ul>
                    <li>Using weak passwords or reusing passwords</li>
                    <li>Storing keys on internet-connected devices</li>
                    <li>Sharing validator credentials</li>
                    <li>Ignoring security updates</li>
                    <li>Not monitoring validator performance</li>
                </ul>
            `,
            category: 'tutorial',
            tags: ['security', 'staking', 'validator', 'best-practices', 'ethereum'],
            date: '2024-01-08',
            readTime: '10 min read',
            author: 'Ethereum Node Setup Team',
            featured: true
        },
        {
            id: 'mev-boost-integration-guide',
            title: 'MEV-Boost Integration: Maximizing Validator Rewards',
            excerpt: 'Learn how to integrate MEV-Boost with your validator to capture additional rewards from block production.',
            content: `
                <h2>What is MEV-Boost?</h2>
                <p>MEV-Boost is a protocol that allows validators to outsource block building to specialized builders, potentially increasing their rewards through Maximum Extractable Value (MEV).</p>
                
                <h3>How MEV-Boost Works</h3>
                <p>The MEV-Boost protocol works through a competitive auction process:</p>
                <ol>
                    <li>Block builders create optimized blocks with MEV opportunities</li>
                    <li>Builders submit their blocks to relays</li>
                    <li>Relays forward the best blocks to validators</li>
                    <li>Validators choose the most profitable block to propose</li>
                </ol>
                
                <h3>Installing MEV-Boost</h3>
                <p>Install MEV-Boost using our automated script:</p>
                <pre><code>./install_mev_boost.sh</code></pre>
                
                <p>Or install manually:</p>
                <pre><code># Download the latest release
wget https://github.com/flashbots/mev-boost/releases/latest/download/mev-boost_1.7.0_linux_amd64.tar.gz

# Extract and install
tar -xzf mev-boost_1.7.0_linux_amd64.tar.gz
sudo mv mev-boost /usr/local/bin/
sudo chmod +x /usr/local/bin/mev-boost</code></pre>
                
                <h3>Configuration</h3>
                <p>Configure MEV-Boost with multiple relays for redundancy:</p>
                <pre><code>mev-boost \\
    -mainnet \\
    -relay-check \\
    -relays https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2ad3ef3b2bd0c73a3047b0c169e0f390c0e@boost-relay.flashbots.net,https://0x8b5d2e73e3a44ad8f4344f7c442d0a4187ac8d6a6bd0e4cdc0a3acbb325da8486e9c9e82f7589607e75c4a6dcf9041c@relay.ultrasound.money,https://0xa1defa73d675983a6972e8686360062c1b2e43f4e83c1a33a9638a2a0da3a0615fce58cc66727c722c116c5120d4dd0c@bloXroute.max-profit.blxrbdn.com</code></pre>
                
                <h3>Validator Integration</h3>
                <p>Configure your consensus client to use MEV-Boost:</p>
                
                <h4>Prysm Configuration</h4>
                <pre><code>--enable-builder \\
--builder-endpoint http://localhost:18550</code></pre>
                
                <h4>Lighthouse Configuration</h4>
                <pre><code>--builder http://localhost:18550</code></pre>
                
                <h4>Teku Configuration</h4>
                <pre><code>--validators-builder-registration-default-enabled=true \\
--builder-endpoint http://localhost:18550</code></pre>
                
                <h3>Testing MEV-Boost</h3>
                <p>Verify MEV-Boost is working correctly:</p>
                <pre><code># Check MEV-Boost status
curl http://localhost:18550/status

# Monitor logs
journalctl -fu mev

# Check validator registration
curl -X POST http://localhost:5052/eth/v1/validator/register_validator \\
  -H "Content-Type: application/json" \\
  -d '{"pubkey": "0x...", "fee_recipient": "0x..."}'</code></pre>
                
                <h3>Monitoring Performance</h3>
                <p>Track MEV-Boost performance and rewards:</p>
                <ul>
                    <li>Monitor block production frequency</li>
                    <li>Track additional rewards earned</li>
                    <li>Watch for relay connectivity issues</li>
                    <li>Monitor validator registration status</li>
                </ul>
                
                <h3>Best Practices</h3>
                <ul>
                    <li>Use multiple relays for redundancy</li>
                    <li>Monitor relay performance regularly</li>
                    <li>Keep MEV-Boost updated</li>
                    <li>Test failover procedures</li>
                    <li>Monitor for slashing conditions</li>
                </ul>
            `,
            category: 'technical',
            tags: ['mev-boost', 'rewards', 'validator', 'block-building', 'optimization'],
            date: '2024-01-05',
            readTime: '9 min read',
            author: 'Ethereum Node Setup Team',
            featured: false
        },
        {
            id: 'ethereum-network-updates-2024',
            title: 'Ethereum Network Updates and Roadmap for 2024',
            excerpt: 'Stay updated with the latest Ethereum network improvements, upcoming upgrades, and what they mean for node operators.',
            content: `
                <h2>Ethereum's Evolution in 2024</h2>
                <p>2024 promises to be another exciting year for Ethereum, with several major upgrades and improvements planned that will affect node operators and validators.</p>
                
                <h3>Recent Upgrades</h3>
                <p>Ethereum has continued to evolve with regular network upgrades:</p>
                
                <h4>Dencun Upgrade (March 2024)</h4>
                <ul>
                    <li>Proto-danksharding (EIP-4844) implementation</li>
                    <li>Reduced transaction costs for Layer 2 solutions</li>
                    <li>Improved data availability for rollups</li>
                    <li>Enhanced scalability for the network</li>
                </ul>
                
                <h3>Upcoming Features</h3>
                <p>Several exciting features are in development:</p>
                
                <h4>EIP-7002: Execution Layer Triggerable Exits</h4>
                <p>This proposal allows validators to trigger exits from the execution layer, improving the user experience for staking withdrawals.</p>
                
                <h4>EIP-6110: Supply Deposits</h4>
                <p>This upgrade will allow validators to be created with deposits supplied at the execution layer, simplifying the staking process.</p>
                
                <h4>EIP-7683: General Purpose Commitments</h4>
                <p>This proposal introduces a general-purpose commitment scheme that can be used for various purposes beyond just withdrawals.</p>
                
                <h3>Client Updates</h3>
                <p>All major clients are working on implementing these features:</p>
                
                <h4>Execution Clients</h4>
                <ul>
                    <li><strong>Geth:</strong> Continued performance optimizations and new feature support</li>
                    <li><strong>Erigon:</strong> Enhanced sync speed and reduced resource usage</li>
                    <li><strong>Reth:</strong> Rapid development with modern architecture</li>
                    <li><strong>Nethermind:</strong> Enterprise features and monitoring improvements</li>
                    <li><strong>Besu:</strong> Enhanced privacy features and compliance tools</li>
                </ul>
                
                <h4>Consensus Clients</h4>
                <ul>
                    <li><strong>Prysm:</strong> Improved checkpoint sync and performance</li>
                    <li><strong>Lighthouse:</strong> Enhanced security features and optimization</li>
                    <li><strong>Teku:</strong> Advanced monitoring and enterprise features</li>
                    <li><strong>Nimbus:</strong> Continued lightweight optimization</li>
                    <li><strong>Lodestar:</strong> Developer-friendly improvements</li>
                    <li><strong>Grandine:</strong> Cutting-edge performance features</li>
                </ul>
                
                <h3>Impact on Node Operators</h3>
                <p>These updates will affect node operators in several ways:</p>
                
                <h4>Performance Improvements</h4>
                <ul>
                    <li>Faster sync times with improved algorithms</li>
                    <li>Reduced resource usage through optimization</li>
                    <li>Better network efficiency and lower costs</li>
                    <li>Enhanced monitoring and debugging tools</li>
                </ul>
                
                <h4>New Features</h4>
                <ul>
                    <li>Improved staking and withdrawal processes</li>
                    <li>Enhanced MEV-Boost integration</li>
                    <li>Better Layer 2 support and monitoring</li>
                    <li>Advanced security features</li>
                </ul>
                
                <h3>Preparing for Updates</h3>
                <p>To stay current with Ethereum updates:</p>
                <ul>
                    <li>Regularly update your client software</li>
                    <li>Monitor official client release notes</li>
                    <li>Test updates on testnets first</li>
                    <li>Join client communities for support</li>
                    <li>Follow Ethereum Foundation announcements</li>
                </ul>
                
                <h3>Resources</h3>
                <p>Stay informed with these resources:</p>
                <ul>
                    <li><a href="https://ethereum.org/en/upgrades/">Ethereum.org Upgrades</a></li>
                    <li><a href="https://github.com/ethereum/consensus-specs">Consensus Layer Specifications</a></li>
                    <li><a href="https://github.com/ethereum/execution-specs">Execution Layer Specifications</a></li>
                    <li><a href="https://ethresear.ch/">Ethereum Research Forum</a></li>
                </ul>
            `,
            category: 'news',
            tags: ['ethereum', 'upgrades', 'roadmap', '2024', 'network-updates'],
            date: '2024-01-03',
            readTime: '12 min read',
            author: 'Ethereum Node Setup Team',
            featured: true
        }
    ],
    categories: ['all', 'tutorial', 'technical', 'news', 'client'],
    currentPage: 1,
    postsPerPage: 6,
    currentFilter: 'all'
};

// DOM elements
const blogGrid = document.getElementById('blog-grid');
const blogPagination = document.getElementById('blog-pagination');
const filterButtons = document.querySelectorAll('.filter-btn');
const totalPostsElement = document.getElementById('total-posts');

// Initialize blog
document.addEventListener('DOMContentLoaded', function() {
    initializeBlog();
    setupEventListeners();
    updateTotalPosts();
});

// Initialize blog functionality
function initializeBlog() {
    renderBlogPosts();
    renderPagination();
}

// Setup event listeners
function setupEventListeners() {
    // Filter buttons
    filterButtons.forEach(button => {
        button.addEventListener('click', function() {
            const filter = this.getAttribute('data-filter');
            setActiveFilter(filter);
            blogData.currentFilter = filter;
            blogData.currentPage = 1;
            renderBlogPosts();
            renderPagination();
        });
    });
    
    // Mobile menu toggle
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');
    
    if (hamburger && navMenu) {
        hamburger.addEventListener('click', function() {
            navMenu.classList.toggle('active');
            hamburger.classList.toggle('active');
        });
    }
}

// Set active filter
function setActiveFilter(filter) {
    filterButtons.forEach(button => {
        button.classList.remove('active');
        if (button.getAttribute('data-filter') === filter) {
            button.classList.add('active');
        }
    });
}

// Get filtered posts
function getFilteredPosts() {
    if (blogData.currentFilter === 'all') {
        return blogData.posts;
    }
    return blogData.posts.filter(post => post.category === blogData.currentFilter);
}

// Get paginated posts
function getPaginatedPosts() {
    const filteredPosts = getFilteredPosts();
    const startIndex = (blogData.currentPage - 1) * blogData.postsPerPage;
    const endIndex = startIndex + blogData.postsPerPage;
    return filteredPosts.slice(startIndex, endIndex);
}

// Render blog posts
function renderBlogPosts() {
    const posts = getPaginatedPosts();
    
    if (posts.length === 0) {
        blogGrid.innerHTML = '<div class="no-posts">No posts found for this filter.</div>';
        return;
    }
    
    blogGrid.innerHTML = posts.map(post => `
        <article class="blog-card" onclick="navigateToArticle('${post.id}')">
            <div class="blog-card-image">
                ${getCategoryIcon(post.category)}
            </div>
            <div class="blog-card-content">
                <span class="blog-card-category">${post.category}</span>
                <h2 class="blog-card-title">${post.title}</h2>
                <p class="blog-card-excerpt">${post.excerpt}</p>
                <div class="blog-card-meta">
                    <span class="blog-card-date">
                        📅 ${formatDate(post.date)}
                    </span>
                    <span class="blog-card-read-time">
                        ⏱️ ${post.readTime}
                    </span>
                </div>
            </div>
        </article>
    `).join('');
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

// Render pagination
function renderPagination() {
    const filteredPosts = getFilteredPosts();
    const totalPages = Math.ceil(filteredPosts.length / blogData.postsPerPage);
    
    if (totalPages <= 1) {
        blogPagination.innerHTML = '';
        return;
    }
    
    let paginationHTML = '';
    
    // Previous button
    if (blogData.currentPage > 1) {
        paginationHTML += `<button class="pagination-btn" onclick="changePage(${blogData.currentPage - 1})">Previous</button>`;
    }
    
    // Page numbers
    for (let i = 1; i <= totalPages; i++) {
        const isActive = i === blogData.currentPage ? 'active' : '';
        paginationHTML += `<button class="pagination-btn ${isActive}" onclick="changePage(${i})">${i}</button>`;
    }
    
    // Next button
    if (blogData.currentPage < totalPages) {
        paginationHTML += `<button class="pagination-btn" onclick="changePage(${blogData.currentPage + 1})">Next</button>`;
    }
    
    blogPagination.innerHTML = paginationHTML;
}

// Change page
function changePage(page) {
    const filteredPosts = getFilteredPosts();
    const totalPages = Math.ceil(filteredPosts.length / blogData.postsPerPage);
    
    if (page >= 1 && page <= totalPages) {
        blogData.currentPage = page;
        renderBlogPosts();
        renderPagination();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

// Navigate to article
function navigateToArticle(articleId) {
    window.location.href = `article.html?id=${articleId}`;
}

// Update total posts count
function updateTotalPosts() {
    if (totalPostsElement) {
        totalPostsElement.textContent = blogData.posts.length;
    }
}

// Search functionality (if needed)
function searchPosts(query) {
    const filteredPosts = getFilteredPosts();
    const searchResults = filteredPosts.filter(post => 
        post.title.toLowerCase().includes(query.toLowerCase()) ||
        post.excerpt.toLowerCase().includes(query.toLowerCase()) ||
        post.tags.some(tag => tag.toLowerCase().includes(query.toLowerCase()))
    );
    
    // Update display with search results
    blogGrid.innerHTML = searchResults.map(post => `
        <article class="blog-card" onclick="navigateToArticle('${post.id}')">
            <div class="blog-card-image">
                ${getCategoryIcon(post.category)}
            </div>
            <div class="blog-card-content">
                <span class="blog-card-category">${post.category}</span>
                <h2 class="blog-card-title">${post.title}</h2>
                <p class="blog-card-excerpt">${post.excerpt}</p>
                <div class="blog-card-meta">
                    <span class="blog-card-date">
                        📅 ${formatDate(post.date)}
                    </span>
                    <span class="blog-card-read-time">
                        ⏱️ ${post.readTime}
                    </span>
                </div>
            </div>
        </article>
    `).join('');
}

// Export blog data for use in other files
window.blogData = blogData;