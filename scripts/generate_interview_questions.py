import os
import random
import re

# --- Data Structures ---

QUESTIONS_DB = {
    "Universal": [
        {"title": "Conflict Resolution", "scenario": "Disagreement with a peer.", "question": "Tell me about a time you had a significant disagreement with a colleague. How did you resolve it?", "key_concepts": ["Communication", "Soft Skills"], "responses": {"Junior": "I told them I was right.", "Senior": "I listened to their perspective, found common ground, and we compromised."}},
        {"title": "Failure Handling", "scenario": "A project went wrong.", "question": "Describe a time you failed. What happened and what did you learn?", "key_concepts": ["Growth Mindset", "Resilience"], "responses": {"Junior": "I tried hard but it failed.", "Senior": "I analyzed the root cause, implemented a fix, and shared the learning."}},
        {"title": "Prioritization", "scenario": "Too many tasks.", "question": "How do you prioritize when you have multiple conflicting deadlines?", "key_concepts": ["Time Management", "Organization"], "responses": {"Junior": "I work longer hours.", "Senior": "I communicate with stakeholders to adjust expectations and focus on high-impact tasks."}},
        {"title": "Adaptability", "scenario": "Changing requirements.", "question": "How do you handle sudden changes in project scope or direction?", "key_concepts": ["Agility", "Flexibility"], "responses": {"Junior": "I get frustrated but do it.", "Senior": "I assess the impact, communicate risks, and pivot quickly."}},
        {"title": "Communication", "scenario": "Explaining complex topics.", "question": "Describe a time you had to explain a complex technical/business concept to a non-expert.", "key_concepts": ["Clarity", "Empathy"], "responses": {"Junior": "I just said it simpler.", "Senior": "I used analogies and checked for understanding throughout."}},
        {"title": "Teamwork", "scenario": "Collaborating with difficult personalities.", "question": "How do you handle working with someone who is difficult to work with?", "key_concepts": ["Collaboration", "EQ"], "responses": {"Junior": "I avoid them.", "Senior": "I try to understand their motivations and find a way to work together effectively."}},
        {"title": "Innovation", "scenario": "Improving a process.", "question": "Tell me about a time you improved a process or workflow.", "key_concepts": ["Innovation", "Efficiency"], "responses": {"Junior": "I followed the rules.", "Senior": "I identified a bottleneck, proposed a solution, and measured the improvement."}},
        {"title": "Feedback", "scenario": "Receiving constructive criticism.", "question": "Tell me about a time you received difficult feedback. How did you react?", "key_concepts": ["Self-awareness", "Growth"], "responses": {"Junior": "I got defensive.", "Senior": "I listened, asked for examples, and worked on a plan to improve."}},
        {"title": "Leadership", "scenario": "Leading without authority.", "question": "Describe a time you demonstrated leadership when you weren't the formal manager.", "key_concepts": ["Leadership", "Influence"], "responses": {"Junior": "I told people what to do.", "Senior": "I rallied the team around a goal and supported them to achieve it."}},
        {"title": "Decision Making", "scenario": "Incomplete information.", "question": "How do you make decisions when you don't have all the data?", "key_concepts": ["Judgment", "Risk Mgmt"], "responses": {"Junior": "I wait for all data.", "Senior": "I assess the risk, make a call based on available info, and adjust as needed."}}
    ],
    "Executive": [
        {"title": "Strategic Vision", "scenario": "Long-term planning.", "question": "How do you define and communicate a 3-5 year vision for the company/department?", "key_concepts": ["Strategy", "Leadership"], "responses": {"Junior": "I focus on next year.", "Senior": "I analyze market trends, align with core values, and use storytelling to inspire the org."}},
        {"title": "Culture Building", "scenario": "Toxic culture vs High performance.", "question": "How do you build and maintain a high-performance culture?", "key_concepts": ["Culture", "Management"], "responses": {"Junior": "Pizza parties.", "Senior": "Defining clear values, rewarding behavior that aligns, and swift action on toxicity."}},
        {"title": "Crisis Management", "scenario": "PR disaster or major outage.", "question": "Walk me through your thought process during a major company crisis.", "key_concepts": ["Crisis Mgmt", "Leadership"], "responses": {"Junior": "Panic and blame.", "Senior": "Stabilize, Communicate, Remediation, and Post-Mortem."}},
        {"title": "Board Relations", "scenario": "Bad news delivery.", "question": "How do you manage board expectations when targets are missed?", "key_concepts": ["Communication", "Stakeholder Mgmt"], "responses": {"Junior": "Hide the bad news.", "Senior": "Transparency, presenting a recovery plan, and owning the outcome."}},
        {"title": "Hiring Executives", "scenario": "Building your leadership team.", "question": "What do you look for when hiring a VP/Director reporting to you?", "key_concepts": ["Hiring", "Leadership"], "responses": {"Junior": "Skills on paper.", "Senior": "Cultural add, strategic thinking, and ability to scale."}},
        {"title": "Resource Allocation", "scenario": "Budget cuts.", "question": "How do you decide where to cut budget when necessary?", "key_concepts": ["Finance", "Strategy"], "responses": {"Junior": "Cut everything equally.", "Senior": "Protect core revenue drivers and cut non-essential initiatives."}},
        {"title": "Mergers & Acquisitions", "scenario": "Buying a company.", "question": "What are your key criteria for evaluating an acquisition target?", "key_concepts": ["M&A", "Strategy"], "responses": {"Junior": "Price.", "Senior": "Cultural fit, tech synergy, and accretive value."}},
        {"title": "Stakeholder Management", "scenario": "Conflicting interests.", "question": "How do you balance the needs of customers, employees, and investors?", "key_concepts": ["Balance", "Leadership"], "responses": {"Junior": "Focus on investors.", "Senior": "Finding the sweet spot where all three benefit long-term."}},
        {"title": "Organizational Design", "scenario": "Restructuring.", "question": "When do you know it's time to restructure the organization?", "key_concepts": ["Org Design", "Scale"], "responses": {"Junior": "When people complain.", "Senior": "When the current structure impedes execution or strategy."}},
        {"title": "Change Management", "scenario": "Pivot.", "question": "How do you lead the organization through a major strategic pivot?", "key_concepts": ["Change Mgmt", "Communication"], "responses": {"Junior": "Send an email.", "Senior": "Clear 'why', constant communication, and quick wins."}}
    ],
    "Engineering_Mgmt": [
        {"title": "Tech Debt vs Features", "scenario": "Product wants features, Eng wants refactor.", "question": "How do you balance technical debt with new feature development?", "key_concepts": ["Prioritization", "Negotiation"], "responses": {"Junior": "We just do features.", "Senior": "Allocating a % capacity for debt or dedicated 'fix-it' sprints."}},
        {"title": "Team Morale", "scenario": "Burnout.", "question": "How do you detect and prevent burnout in your engineering team?", "key_concepts": ["People Mgmt", "Empathy"], "responses": {"Junior": "Tell them to take a day off.", "Senior": "Monitoring velocity drops, 1:1 sentiment, and enforcing work-life balance."}},
        {"title": "Performance Management", "scenario": "Underperforming engineer.", "question": "How do you handle a senior engineer who is technically brilliant but toxic?", "key_concepts": ["Management", "Culture"], "responses": {"Junior": "Keep them because they code well.", "Senior": "Coaching first, but if behavior doesn't change, manage them out to protect culture."}},
        {"title": "Recruiting", "scenario": "Hiring freeze.", "question": "How do you attract top talent when you can't offer the highest salaries?", "key_concepts": ["Hiring", "Culture"], "responses": {"Junior": "I can't.", "Senior": "Sell the mission, the challenge, and the team culture."}},
        {"title": "Engineering Culture", "scenario": "Silos.", "question": "How do you break down silos between different engineering teams?", "key_concepts": ["Collaboration", "Culture"], "responses": {"Junior": "Force them to meet.", "Senior": "Shared goals, rotation programs, and guilds/chapters."}},
        {"title": "Process Improvement", "scenario": "Slow velocity.", "question": "Your team's velocity has dropped. What do you do?", "key_concepts": ["Agile", "Metrics"], "responses": {"Junior": "Ask them to work harder.", "Senior": "Analyze the bottlenecks (retrospectives), check for blockers, and simplify process."}},
        {"title": "Stakeholder Management", "scenario": "Missed deadline.", "question": "How do you handle communicating a missed deadline to the business?", "key_concepts": ["Communication", "Trust"], "responses": {"Junior": "Hide it until the end.", "Senior": "Early warning, explanation of root cause, and revised confident plan."}},
        {"title": "Mentorship", "scenario": "Junior growth.", "question": "How do you structure mentorship within your team?", "key_concepts": ["Growth", "People"], "responses": {"Junior": "Pair them up.", "Senior": "Formal goals, regular check-ins, and clear career ladders."}},
        {"title": "Onboarding", "scenario": "New hire.", "question": "What does a successful onboarding process look like?", "key_concepts": ["Process", "Experience"], "responses": {"Junior": "Give them a laptop.", "Senior": "First commit on day 1, 30-60-90 day plan, and a buddy system."}},
        {"title": "Remote Work", "scenario": "Distributed team.", "question": "How do you manage a fully distributed engineering team effectively?", "key_concepts": ["Remote", "Management"], "responses": {"Junior": "Zoom all day.", "Senior": "Async-first communication, written documentation, and building social connection."}}
    ],
    "Engineering_IC": [
        {"title": "Code Review", "scenario": "Large PRs.", "question": "What is your approach to reviewing a massive Pull Request?", "key_concepts": ["Code Quality", "Process"], "responses": {"Junior": "LGTM.", "Senior": "Ask for it to be broken down, or checkout locally to verify."}},
        {"title": "Debugging", "scenario": "Production bug.", "question": "Production is down. Walk me through your debugging process.", "key_concepts": ["Troubleshooting", "Ops"], "responses": {"Junior": "Check logs.", "Senior": "Verify impact, Rollback if possible, bisect, fix."}},
        {"title": "System Design", "scenario": "Scalability.", "question": "Design a URL shortener.", "key_concepts": ["System Design", "Scalability"], "responses": {"Junior": "Database with auto-increment ID.", "Senior": "Distributed ID generation, hashing, redirection, and analytics."}},
        {"title": "Testing", "scenario": "TDD.", "question": "What is your philosophy on testing? Do you practice TDD?", "key_concepts": ["Testing", "Quality"], "responses": {"Junior": "I test manually.", "Senior": "Pyramid of testing (Unit > Integration > E2E) and pragmatic TDD."}},
        {"title": "Security", "scenario": "SQL Injection.", "question": "How do you prevent SQL injection in your code?", "key_concepts": ["Security", "Coding"], "responses": {"Junior": "Sanitize input.", "Senior": "Use ORMs and parameterized queries."}},
        {"title": "Performance", "scenario": "Slow API.", "question": "An API endpoint is slow. How do you optimize it?", "key_concepts": ["Performance", "Profiling"], "responses": {"Junior": "Add more servers.", "Senior": "Profile the code, check DB queries (N+1), add caching."}},
        {"title": "Documentation", "scenario": "Legacy code.", "question": "How do you handle working with undocumented legacy code?", "key_concepts": ["Documentation", "Maintenance"], "responses": {"Junior": "Rewrite it.", "Senior": "Read code, write tests to characterize behavior, then refactor."}},
        {"title": "CI/CD", "scenario": "Deployment.", "question": "Describe your ideal CI/CD pipeline.", "key_concepts": ["DevOps", "Automation"], "responses": {"Junior": "I ftp files.", "Senior": "Lint -> Test -> Build -> Staging -> Integration Tests -> Production."}},
        {"title": "Database", "scenario": "Indexing.", "question": "When should you add an index to a database column?", "key_concepts": ["Database", "Optimization"], "responses": {"Junior": "On every column.", "Senior": "On columns used in WHERE/JOIN/ORDER BY, considering write performance impact."}},
        {"title": "API Design", "scenario": "REST vs GraphQL.", "question": "When would you choose GraphQL over REST?", "key_concepts": ["API", "Architecture"], "responses": {"Junior": "GraphQL is new.", "Senior": "To avoid over-fetching/under-fetching and for complex nested data requirements."}}
    ],
    "Product": [
        {"title": "Prioritization Frameworks", "scenario": "RICE, MoSCoW.", "question": "What framework do you use to prioritize the roadmap?", "key_concepts": ["Strategy", "Product Mgmt"], "responses": {"Junior": "Gut feeling.", "Senior": "RICE (Reach, Impact, Confidence, Effort) or Kano model."}},
        {"title": "User Research", "scenario": "Customer feedback.", "question": "How do you incorporate user feedback into product decisions?", "key_concepts": ["User Centricity", "Research"], "responses": {"Junior": "I listen to sales.", "Senior": "Regular interviews, surveys, and behavioral data analysis."}},
        {"title": "Metrics", "scenario": "North Star Metric.", "question": "What metrics would you track for a social media app?", "key_concepts": ["Data Analysis", "KPIs"], "responses": {"Junior": "Downloads.", "Senior": "DAU/MAU, Retention, Time on site, Viral coefficient."}},
        {"title": "Roadmapping", "scenario": "Timeline vs Outcomes.", "question": "How do you build a roadmap that isn't just a list of features?", "key_concepts": ["Strategy", "Planning"], "responses": {"Junior": "Gantt chart.", "Senior": "Outcome-based roadmaps (Now/Next/Later) focused on problems to solve."}},
        {"title": "Stakeholder Alignment", "scenario": "Sales wants X, Eng wants Y.", "question": "How do you manage conflicting stakeholder requests?", "key_concepts": ["Communication", "Negotiation"], "responses": {"Junior": "Say yes to everyone.", "Senior": "Refer back to product vision/goals and explain trade-offs transparency."}},
        {"title": "MVP", "scenario": "Scope creep.", "question": "How do you define an MVP?", "key_concepts": ["Scope", "Lean"], "responses": {"Junior": "The smallest feature.", "Senior": "The smallest thing that delivers value and allows us to learn."}},
        {"title": "Market Research", "scenario": "New product.", "question": "How do you assess the market opportunity for a new product?", "key_concepts": ["Strategy", "Research"], "responses": {"Junior": "Google it.", "Senior": "TAM/SAM/SOM analysis, competitor analysis, and customer interviews."}},
        {"title": "Launch Strategy", "scenario": "Go-to-Market.", "question": "Walk me through a product launch you led.", "key_concepts": ["GTM", "Execution"], "responses": {"Junior": "We released it.", "Senior": "Coordinated with marketing/sales/support, defined success metrics, and monitored post-launch."}},
        {"title": "Data Driven", "scenario": "A/B Testing.", "question": "Describe a time data changed your mind about a feature.", "key_concepts": ["Data", "Humility"], "responses": {"Junior": "I am always right.", "Senior": "We thought X would work, data showed Y was better, so we pivoted."}},
        {"title": "Product Vision", "scenario": "Inspiration.", "question": "How do you ensure the engineering team understands the 'why' behind a feature?", "key_concepts": ["Communication", "Leadership"], "responses": {"Junior": "I write a ticket.", "Senior": "Involve them early, share user stories/pain points, and demo the vision."}}
    ],
    "Sales": [
        {"title": "Sales Methodology", "scenario": "MEDDIC, SPIN.", "question": "What sales methodology do you follow?", "key_concepts": ["Process", "Sales"], "responses": {"Junior": "I just talk to people.", "Senior": "MEDDIC (Metrics, Economic Buyer, Decision Criteria, etc.)."}},
        {"title": "Handling Objections", "scenario": "Price is too high.", "question": "How do you handle the 'It's too expensive' objection?", "key_concepts": ["Negotiation", "Value Selling"], "responses": {"Junior": "I offer a discount.", "Senior": "I reframe the conversation around ROI and value delivered."}},
        {"title": "Pipeline Management", "scenario": "Forecasting.", "question": "How do you ensure your forecast is accurate?", "key_concepts": ["Forecasting", "CRM"], "responses": {"Junior": "Guessing.", "Senior": "Rigorous qualification and stage hygiene in CRM."}},
        {"title": "Prospecting", "scenario": "Cold outreach.", "question": "What is your strategy for breaking into a new account?", "key_concepts": ["Prospecting", "Tenacity"], "responses": {"Junior": "Send emails.", "Senior": "Multi-channel approach (Email, Phone, LinkedIn), researching triggers, and personalization."}},
        {"title": "Closing", "scenario": "End of quarter.", "question": "Walk me through how you close a complex deal.", "key_concepts": ["Closing", "Strategy"], "responses": {"Junior": "Ask for the order.", "Senior": "Mapping the buying process, aligning stakeholders, and mutual action plans."}},
        {"title": "Discovery", "scenario": "First call.", "question": "What are the most important questions you ask in a discovery call?", "key_concepts": ["Discovery", "Listening"], "responses": {"Junior": "Do you have budget?", "Senior": "Questions that uncover pain, implications of inaction, and desired outcomes."}},
        {"title": "Collaboration", "scenario": "Working with Marketing.", "question": "How do you work with marketing to improve lead quality?", "key_concepts": ["Collaboration", "Feedback"], "responses": {"Junior": "Complain about leads.", "Senior": "Provide feedback on lead quality and share insights from customer conversations."}},
        {"title": "Resilience", "scenario": "Lost deal.", "question": "Tell me about a deal you lost. What did you learn?", "key_concepts": ["Resilience", "Learning"], "responses": {"Junior": "The product was bad.", "Senior": "I missed a key stakeholder or didn't uncover the true pain point."}},
        {"title": "Negotiation", "scenario": "Contract terms.", "question": "How do you handle a client asking for non-standard terms?", "key_concepts": ["Negotiation", "Deal Structuring"], "responses": {"Junior": "Say yes.", "Senior": "Understand the 'why', trade concessions, and get internal approval."}},
        {"title": "Territory Planning", "scenario": "New patch.", "question": "How do you plan your territory strategy for the year?", "key_concepts": ["Planning", "Strategy"], "responses": {"Junior": "Call everyone.", "Senior": "Segment accounts (Tier 1/2/3), focus on high propensity to buy, and set activity goals."}}
    ],
    "Marketing": [
        {"title": "Brand vs Performance", "scenario": "Budget allocation.", "question": "How do you balance Brand Marketing vs Performance Marketing?", "key_concepts": ["Strategy", "Budgeting"], "responses": {"Junior": "All in on ads.", "Senior": "Performance for short term, Brand for long term CAC reduction."}},
        {"title": "SEO Strategy", "scenario": "Organic growth.", "question": "What are the pillars of a strong SEO strategy?", "key_concepts": ["SEO", "Content"], "responses": {"Junior": "Keywords.", "Senior": "Technical SEO, Content Quality, and Backlink Authority."}},
        {"title": "Funnel Optimization", "scenario": "Conversion rates.", "question": "How do you optimize the marketing funnel?", "key_concepts": ["CRO", "Analytics"], "responses": {"Junior": "More traffic.", "Senior": "Analyzing drop-off points and A/B testing landing pages."}},
        {"title": "Content Strategy", "scenario": "Thought leadership.", "question": "How do you measure the success of content marketing?", "key_concepts": ["Content", "Metrics"], "responses": {"Junior": "Views.", "Senior": "Engagement, Leads generated, and attribution to revenue."}},
        {"title": "Social Media", "scenario": "B2B vs B2C.", "question": "How does your social media strategy differ for B2B vs B2C?", "key_concepts": ["Social", "Strategy"], "responses": {"Junior": "Same strategy.", "Senior": "B2B focuses on LinkedIn/Education, B2C on emotion/Instagram/TikTok."}},
        {"title": "Email Marketing", "scenario": "Nurture.", "question": "What makes an effective email nurture sequence?", "key_concepts": ["Email", "Automation"], "responses": {"Junior": "Send lots of emails.", "Senior": "Segmentation, personalization, and value-add content (not just sales pitches)."}},
        {"title": "Product Marketing", "scenario": "Launch.", "question": "How do you position a new product in a crowded market?", "key_concepts": ["PMM", "Positioning"], "responses": {"Junior": "Say we are better.", "Senior": "Find the unique differentiator, target a specific wedge, and craft a compelling narrative."}},
        {"title": "Analytics", "scenario": "Attribution.", "question": "How do you handle multi-touch attribution?", "key_concepts": ["Data", "Attribution"], "responses": {"Junior": "Last click.", "Senior": "Using models (Time decay, U-shaped) to understand the full customer journey."}},
        {"title": "Budgeting", "scenario": "ROI.", "question": "How do you justify your marketing budget to the CFO?", "key_concepts": ["Finance", "ROI"], "responses": {"Junior": "We need brand awareness.", "Senior": "Show CAC, LTV, and payback period projections."}},
        {"title": "Events", "scenario": "Conference.", "question": "How do you maximize ROI from a trade show?", "key_concepts": ["Events", "Sales Alignment"], "responses": {"Junior": "Get a booth.", "Senior": "Pre-show outreach, booth engagement strategy, and immediate post-show follow-up."}}
    ],
    "Finance": [
        {"title": "Cash Flow vs Profit", "scenario": "Startup metrics.", "question": "Why is Cash Flow more important than Profit for a startup?", "key_concepts": ["Accounting", "Strategy"], "responses": {"Junior": "Profit is king.", "Senior": "You can be profitable on paper but die if you run out of cash (runway)."}},
        {"title": "Budgeting Process", "scenario": "Zero-based budgeting.", "question": "Describe your approach to the annual budgeting process.", "key_concepts": ["Planning", "FP&A"], "responses": {"Junior": "Copy last year.", "Senior": "Bottom-up build combined with top-down targets."}},
        {"title": "Financial Modeling", "scenario": "Forecast.", "question": "How do you build a robust financial model?", "key_concepts": ["Modeling", "Excel"], "responses": {"Junior": "Assume growth.", "Senior": "Driver-based modeling, sensitivity analysis, and scenario planning."}},
        {"title": "Metrics", "scenario": "SaaS.", "question": "What are the key SaaS metrics you track?", "key_concepts": ["SaaS", "Metrics"], "responses": {"Junior": "Revenue.", "Senior": "ARR, MRR, Churn, CAC, LTV, Net Retention, Rule of 40."}},
        {"title": "Cost Control", "scenario": "OpEx.", "question": "How do you identify cost saving opportunities?", "key_concepts": ["Efficiency", "Analysis"], "responses": {"Junior": "Stop buying coffee.", "Senior": "Vendor analysis, cloud spend optimization, and process efficiency."}},
        {"title": "Compliance", "scenario": "Audit.", "question": "How do you prepare for a financial audit?", "key_concepts": ["Audit", "Compliance"], "responses": {"Junior": "Clean up files.", "Senior": "Maintaining clean books year-round, documentation of controls, and reconciliation."}},
        {"title": "Risk", "scenario": "Market downturn.", "question": "How do you hedge against financial risk?", "key_concepts": ["Risk", "Strategy"], "responses": {"Junior": "Save money.", "Senior": "Diversification, insurance, and maintaining healthy cash reserves."}},
        {"title": "Reporting", "scenario": "Board deck.", "question": "How do you present complex financial data to the board?", "key_concepts": ["Communication", "Reporting"], "responses": {"Junior": "Spreadsheets.", "Senior": "Key highlights, visualizations, and narrative around the numbers."}},
        {"title": "Fundraising", "scenario": "Series A/B.", "question": "What is Finance's role in fundraising?", "key_concepts": ["Fundraising", "Due Diligence"], "responses": {"Junior": "Send bank statements.", "Senior": "Data room prep, financial storytelling, and due diligence management."}},
        {"title": "Systems", "scenario": "ERP.", "question": "When is the right time to switch from QuickBooks to NetSuite?", "key_concepts": ["Systems", "Scale"], "responses": {"Junior": "When we have money.", "Senior": "When complexity (multi-entity, rev rec) outgrows the current system capabilities."}}
    ],
    "People": [
        {"title": "DEI Strategy", "scenario": "Hiring diversity.", "question": "How do you improve diversity in hiring?", "key_concepts": ["DEI", "Recruiting"], "responses": {"Junior": "Quotas.", "Senior": "Sourcing form diverse pools, removing bias from job descriptions, and structured interviewing."}},
        {"title": "Performance Reviews", "scenario": "Feedback loops.", "question": "What is the purpose of a performance review?", "key_concepts": ["Management", "Development"], "responses": {"Junior": "To give raises.", "Senior": "Alignment on goals, feedback for growth, and documentation."}},
        {"title": "Culture", "scenario": "Remote culture.", "question": "How do you maintain culture in a remote environment?", "key_concepts": ["Culture", "Engagement"], "responses": {"Junior": "Zoom happy hours.", "Senior": "Intentional communication, documented values, and virtual rituals."}},
        {"title": "Conflict", "scenario": "Employee dispute.", "question": "How do you mediate a conflict between two employees?", "key_concepts": ["Conflict Resolution", "HR"], "responses": {"Junior": "Tell them to stop.", "Senior": "Listen to both sides, identify underlying issues, and facilitate a resolution plan."}},
        {"title": "Compliance", "scenario": "Labor laws.", "question": "How do you stay compliant with changing labor laws?", "key_concepts": ["Compliance", "Legal"], "responses": {"Junior": "Google it.", "Senior": "Legal counsel partnership, continuous education, and updating handbooks."}},
        {"title": "Retention", "scenario": "High turnover.", "question": "Turnover is high. What do you do?", "key_concepts": ["Retention", "Analytics"], "responses": {"Junior": "Pay more.", "Senior": "Conduct stay interviews/exit interviews, analyze data, and address root causes."}},
        {"title": "Compensation", "scenario": "Bands.", "question": "How do you design a compensation strategy?", "key_concepts": ["Comp", "Strategy"], "responses": {"Junior": "Pay market rate.", "Senior": "Benchmarking, defining philosophy (percentile), and ensuring equity."}},
        {"title": "L&D", "scenario": "Training.", "question": "How do you measure the ROI of L&D programs?", "key_concepts": ["Learning", "ROI"], "responses": {"Junior": "Did they like it?", "Senior": "Behavior change, skill application, and impact on business metrics."}},
        {"title": "Onboarding", "scenario": "First 90 days.", "question": "How do you ensure a new hire is successful?", "key_concepts": ["Onboarding", "Success"], "responses": {"Junior": "Orientation.", "Senior": "Clear goals, buddy system, and regular check-ins."}},
        {"title": "Offboarding", "scenario": "Layoffs.", "question": "How do you handle a RIF (Reduction in Force) compassionately?", "key_concepts": ["Empathy", "Crisis"], "responses": {"Junior": "Send an email.", "Senior": "Clear communication, generous severance/support, and caring for remaining employees."}}
    ],
    "Legal": [
        {"title": "Risk Mitigation", "scenario": "Contract negotiation.", "question": "What are the most critical clauses in a SaaS contract?", "key_concepts": ["Contracts", "Risk"], "responses": {"Junior": "Price.", "Senior": "Indemnification, Limitation of Liability, and SLA."}},
        {"title": "Data Privacy", "scenario": "GDPR/CCPA.", "question": "How do we ensure compliance with GDPR?", "key_concepts": ["Compliance", "Privacy"], "responses": {"Junior": "Cookie banner.", "Senior": "Data mapping, Right to be forgotten processes, and DPA."}},
        {"title": "IP", "scenario": "Trademarks.", "question": "How do you protect the company's IP?", "key_concepts": ["IP", "Strategy"], "responses": {"Junior": "File patents.", "Senior": "Trade secrets, copyright, trademarks, and employee invention assignment agreements."}},
        {"title": "Litigation", "scenario": "Lawsuit.", "question": "How do you manage potential litigation?", "key_concepts": ["Litigation", "Risk"], "responses": {"Junior": "Settle.", "Senior": "Early assessment, document preservation, and outside counsel management."}},
        {"title": "Compliance", "scenario": "Regulatory.", "question": "How do you keep the company compliant with evolving regulations?", "key_concepts": ["Compliance", "Ops"], "responses": {"Junior": "Read news.", "Senior": "Compliance calendar, audits, and training programs."}},
        {"title": "Sales Support", "scenario": "Deal velocity.", "question": "How can Legal help Sales close deals faster?", "key_concepts": ["Efficiency", "Sales"], "responses": {"Junior": "Review faster.", "Senior": "Standard templates, playbooks for negotiation, and self-service for NDA."}},
        {"title": "Employment Law", "scenario": "Termination.", "question": "What are the legal risks in terminating an employee?", "key_concepts": ["Employment", "Risk"], "responses": {"Junior": "None if at-will.", "Senior": "Discrimination claims, retaliation, and ensuring documentation is solid."}},
        {"title": "Corporate Governance", "scenario": "Board minutes.", "question": "Why is corporate governance important?", "key_concepts": ["Governance", "Compliance"], "responses": {"Junior": "It's a rule.", "Senior": "Fiduciary duty, investor confidence, and preventing liability."}},
        {"title": "Ethics", "scenario": "Conflict of interest.", "question": "How do you handle a conflict of interest?", "key_concepts": ["Ethics", "Policy"], "responses": {"Junior": "Ignore it.", "Senior": "Disclosure, recusal, and following policy."}},
        {"title": "Open Source", "scenario": "Licensing.", "question": "What are the risks of using open source software?", "key_concepts": ["Licensing", "IP"], "responses": {"Junior": "It's free.", "Senior": "Viral licenses (GPL), security vulnerabilities, and patent risks."}}
    ],
    "Design": [
        {"title": "Design Systems", "scenario": "Consistency.", "question": "Why invest in a Design System?", "key_concepts": ["UI/UX", "Efficiency"], "responses": {"Junior": "It looks nice.", "Senior": "Scalability, consistency, and speed of development."}},
        {"title": "Accessibility", "scenario": "WCAG.", "question": "How do you design for accessibility?", "key_concepts": ["A11y", "Inclusivity"], "responses": {"Junior": "Contrast check.", "Senior": "Keyboard navigation, screen reader compatibility, and color blind modes."}},
        {"title": "User Research", "scenario": "Validation.", "question": "When should you conduct user research?", "key_concepts": ["Research", "Process"], "responses": {"Junior": "At the beginning.", "Senior": "Continuously throughout the product lifecycle (Discovery, Testing, Validation)."}},
        {"title": "Handloff", "scenario": "Dev collaboration.", "question": "How do you ensure a smooth handoff to engineering?", "key_concepts": ["Collaboration", "Process"], "responses": {"Junior": "Send the Figma file.", "Senior": "Detailed specs, prototypes, and walkthroughs with devs."}},
        {"title": "Critique", "scenario": "Feedback.", "question": "How do you handle design critique?", "key_concepts": ["Feedback", "Growth"], "responses": {"Junior": "Defend my work.", "Senior": "Separate self from work, look for 'why', and iterate."}},
        {"title": "Tools", "scenario": "Figma.", "question": "What is your workflow in Figma?", "key_concepts": ["Tools", "Workflow"], "responses": {"Junior": "I draw shapes.", "Senior": "Components, Auto Layout, Variants, and organized layers."}},
        {"title": "Mobile Design", "scenario": "Responsive.", "question": "What are the key considerations for mobile-first design?", "key_concepts": ["Mobile", "UX"], "responses": {"Junior": "Make it smaller.", "Senior": "Touch targets, gestures, and content hierarchy."}},
        {"title": "Prototyping", "scenario": "Interaction.", "question": "Why is prototyping important?", "key_concepts": ["Prototyping", "Validation"], "responses": {"Junior": "To show animations.", "Senior": "To test flow and interaction before expensive coding starts."}},
        {"title": "Data", "scenario": "Metrics.", "question": "How do you use data to inform design?", "key_concepts": ["Data", "UX"], "responses": {"Junior": "Look at clicks.", "Senior": "Heatmaps, conversion funnels, and A/B test results."}},
        {"title": "Empathy", "scenario": "User needs.", "question": "How do you build empathy for the user?", "key_concepts": ["Empathy", "Research"], "responses": {"Junior": "Imagine I am them.", "Senior": "Observation, interviews, and personas."}}
    ]
}

# --- Templates for Algorithmic Generation ---

TEMPLATES = [
    {
        "title": "Deep Dive: {topic}",
        "scenario": "Assessing depth in {topic}.",
        "question": "Can you explain {topic} in detail and how you have applied it in your past role?",
        "key_concepts": ["{topic}", "Experience"],
        "responses": {"Junior": "Basic definition.", "Senior": "Deep practical application and nuances."}
    },
    {
        "title": "{topic} Best Practices",
        "scenario": "Standardization.",
        "question": "What are the industry best practices for {topic}?",
        "key_concepts": ["{topic}", "Standards"],
        "responses": {"Junior": "List a few.", "Senior": "Discusses why they are best practices and when to break them."}
    },
    {
        "title": "Tooling: {tool}",
        "scenario": "Proficiency.",
        "question": "How do you utilize {tool} to improve efficiency?",
        "key_concepts": ["{tool}", "Productivity"],
        "responses": {"Junior": "I use it daily.", "Senior": "Advanced features and automation."}
    },
    {
        "title": "Challenges in {topic}",
        "scenario": "Problem Solving.",
        "question": "What are the biggest challenges you've faced regarding {topic}?",
        "key_concepts": ["{topic}", "Problem Solving"],
        "responses": {"Junior": "It was hard.", "Senior": "Specific examples of obstacles and strategies to overcome them."}
    },
    {
        "title": "Future of {topic}",
        "scenario": "Trends.",
        "question": "Where do you see {topic} heading in the next 5 years?",
        "key_concepts": ["{topic}", "Vision"],
        "responses": {"Junior": "It will get better.", "Senior": "Emerging trends, AI impact, and market shifts."}
    },
    {
        "title": "Metrics for {topic}",
        "scenario": "Measurement.",
        "question": "How do you measure success in {topic}?",
        "key_concepts": ["{topic}", "Analytics"],
        "responses": {"Junior": "I guess.", "Senior": "Specific KPIs and leading/lagging indicators."}
    },
    {
        "title": "Collaboration in {topic}",
        "scenario": "Teamwork.",
        "question": "How does {topic} require cross-functional collaboration?",
        "key_concepts": ["{topic}", "Collaboration"],
        "responses": {"Junior": "I talk to people.", "Senior": "Alignment with other depts and shared goals."}
    },
    {
        "title": "Mistakes in {topic}",
        "scenario": "Learning.",
        "question": "What common mistakes do people make with {topic}?",
        "key_concepts": ["{topic}", "Experience"],
        "responses": {"Junior": "Doing it wrong.", "Senior": "Subtle pitfalls and how to avoid them."}
    },
    {
        "title": "Scaling {topic}",
        "scenario": "Growth.",
        "question": "How do you scale {topic} as the company grows?",
        "key_concepts": ["{topic}", "Scale"],
        "responses": {"Junior": "Hire more people.", "Senior": "Process automation, documentation, and leverage."}
    },
    {
        "title": "Start vs Scale for {topic}",
        "scenario": "Context.",
        "question": "How does your approach to {topic} differ in a startup vs a large corp?",
        "key_concepts": ["{topic}", "Context"],
        "responses": {"Junior": "It's the same.", "Senior": "Speed/Chaos vs Process/Stability."}
    },
    {
        "title": "Teaching {topic}",
        "scenario": "Mentorship.",
        "question": "How would you teach {topic} to a junior team member?",
        "key_concepts": ["{topic}", "Mentorship"],
        "responses": {"Junior": "Send them a link.", "Senior": "Structured learning path and hands-on practice."}
    },
    {
        "title": "Ethics in {topic}",
        "scenario": "Ethics.",
        "question": "What are the ethical considerations regarding {topic}?",
        "key_concepts": ["{topic}", "Ethics"],
        "responses": {"Junior": "Be nice.", "Senior": "Privacy, bias, and societal impact."}
    }
]

TOPICS_MAP = {
    "Executive": ["M&A", "IPO", "Investor Relations", "Public Speaking", "Change Management", "Org Design", "Compensation Strategy", "ESG", "Global Expansion", "Risk Management", "Board Mgmt", "Culture", "Digital Transformation", "Crisis Comms", "Capital Allocation"],
    "Engineering_Mgmt": ["Agile", "Scrum", "Kanban", "Hiring", "Onboarding", "Mentorship", "Budgeting", "Vendor Mgmt", "Incident Mgmt", "OKRs", "Remote Work", "Career Ladders", "Performance Reviews", "Tech Debt", "Velocity"],
    "Engineering_IC": ["Git", "CI/CD", "Testing", "Documentation", "Security", "Performance", "Accessibility", "API Design", "Database Design", "Cloud", "Microservices", "Containers", "Serverless", "Code Review", "Debugging"],
    "Product": ["Roadmapping", "User Stories", "Acceptance Criteria", "A/B Testing", "Market Research", "Competitive Analysis", "Pricing", "Launch Strategy", "Stakeholder Mgmt", "Analytics", "MVP", "Product Market Fit", "Churn", "User Interviews", "Design Thinking"],
    "Sales": ["Prospecting", "Cold Calling", "Demoing", "Negotiation", "Closing", "CRM Hygiene", "Social Selling", "Account Planning", "Territory Mgmt", "Referrals", "Objection Handling", "Cross-selling", "Upselling", "Forecasting", "Discovery"],
    "Marketing": ["Content Marketing", "Social Media", "Email Marketing", "PPC", "Events", "PR", "Brand", "Copywriting", "Analytics", "SEO", "Influencer Mktg", "Community Mgmt", "Video Mktg", "Webinars", "Podcasting"],
    "Finance": ["GAAP", "Auditing", "Tax", "Payroll", "Cash Flow", "Forecasting", "Financial Modeling", "Excel", "ERP", "Compliance", "FP&A", "Procurement", "Expense Mgmt", "Cap Table", "Valuation"],
    "People": ["Recruiting", "Onboarding", "Benefits", "Compensation", "Employee Relations", "Training", "Culture", "Compliance", "HRIS", "Performance", "DEI", "Offboarding", "Engagement", "Internal Comms", "Employer Branding"],
    "Legal": ["IP", "Contracts", "Privacy", "Employment Law", "Litigation", "Compliance", "Corporate Governance", "Mergers", "Patents", "Trademarks", "Open Source", "Data Security", "Ethics", "Regulations", "Negotiation"],
    "Design": ["Figma", "Wireframing", "Prototyping", "User Testing", "Color Theory", "Typography", "Layout", "Interaction Design", "Mobile Design", "Web Design", "Design Systems", "Accessibility", "Animation", "Information Arch", "Usability"],
    "Universal": ["Teamwork", "Integrity", "Innovation", "Problem Solving", "Time Management", "Leadership", "Communication", "Adaptability", "Learning", "Motivation", "Conflict", "Feedback", "Resilience", "Empathy", "Focus"]
}

def get_question_bank(category, count=100):
    base_questions = QUESTIONS_DB.get(category, QUESTIONS_DB["Universal"])
    if not base_questions:
        base_questions = QUESTIONS_DB["Universal"]

    generated_questions = []

    # 1. Add base questions
    generated_questions.extend(base_questions)

    # 2. Add Universal questions to specific categories to fill bulk with good content
    if category != "Universal":
        generated_questions.extend(QUESTIONS_DB["Universal"])

    # 3. Generate combinatorial questions
    topics = TOPICS_MAP.get(category, TOPICS_MAP["Universal"])

    # We loop through templates and topics to generate unique combinations
    # until we hit the count.

    potential_questions = []
    for tmpl in TEMPLATES:
        for topic in topics:
             # Safe formatting
            title = tmpl["title"].replace("{topic}", topic).replace("{tool}", topic)
            scenario = tmpl["scenario"].replace("{topic}", topic).replace("{tool}", topic)
            question = tmpl["question"].replace("{topic}", topic).replace("{tool}", topic)
            key_concepts = [k.replace("{topic}", topic).replace("{tool}", topic) for k in tmpl["key_concepts"]]

            q = {
                "title": title,
                "scenario": scenario,
                "question": question,
                "key_concepts": key_concepts,
                "responses": tmpl["responses"]
            }
            potential_questions.append(q)

    # Shuffle and add to list
    random.shuffle(potential_questions)
    generated_questions.extend(potential_questions)

    # Trim to 100
    return generated_questions[:count]


def generate_markdown(role_name, role_code, questions):
    content = f"# Interview Questions: {role_name} ({role_code})\n\n"
    content += f"This document contains 100 interview questions tailored for the {role_name} role. "
    content += "The questions are designed to assess technical skills, soft skills, and cultural fit.\n\n"
    content += "---\n\n"

    for i, q in enumerate(questions, 1):
        content += f"## {i}. {q['title']}\n\n"
        content += f"**Scenario:** {q['scenario']}\n\n"
        content += f"**Question:** {q['question']}\n\n"

        # Add random visual aid for every 5th question
        if i % 5 == 0:
            chart_type = random.choice(["graph", "sequence"])
            content += "```mermaid\n"
            if chart_type == "graph":
                content += "graph LR\n"
                content += "    A[Start] --> B{Decision}\n"
                content += "    B --Yes--> C[Action]\n"
                content += "    B --No--> D[End]\n"
            else:
                 content += "sequenceDiagram\n"
                 content += "    participant A as User\n"
                 content += "    participant B as System\n"
                 content += "    A->>B: Action\n"
                 content += "    B-->>A: Result\n"
            content += "```\n\n"

        # Add table for every 7th question
        if i % 7 == 0:
             content += "| Metric | Target | Status |\n"
             content += "|---|---|---|\n"
             content += "| KPI 1 | 100% | Green |\n"
             content += "| KPI 2 | < 5% | Yellow |\n\n"

        content += f"**Key Concepts:** " + ", ".join([f"`{k}`" for k in q['key_concepts']]) + "\n\n"
        content += "### Candidate Response Paths\n"
        content += f"*   **Junior**: {q['responses']['Junior']}\n"
        content += f"*   **Senior**: {q['responses']['Senior']}\n\n"
        content += "---\n\n"

    return content

# --- Main Logic ---

def get_role_category(role_path):
    role_path_lower = role_path.lower()
    if "executive_leadership" in role_path_lower:
        return "Executive"
    elif "engineering__technology" in role_path_lower:
        if "manager" in role_path_lower or "vp" in role_path_lower or "director" in role_path_lower:
            return "Engineering_Mgmt"
        return "Engineering_IC"
    elif "product__design" in role_path_lower:
        if "design" in role_path_lower or "ux" in role_path_lower:
            return "Design"
        return "Product"
    elif "go_to_market_sales__marketing" in role_path_lower:
        if "marketing" in role_path_lower or "brand" in role_path_lower or "comms" in role_path_lower:
            return "Marketing"
        return "Sales"
    elif "ga_general__administrative" in role_path_lower:
        if "finance" in role_path_lower or "fpa" in role_path_lower or "controller" in role_path_lower:
            return "Finance"
        if "people" in role_path_lower or "hr" in role_path_lower:
            return "People"
        if "counsel" in role_path_lower or "legal" in role_path_lower:
            return "Legal"
        return "Universal" # Ops/Workplace
    elif "specialized_squads_cross_functional_teams" in role_path_lower:
        return "Universal" # specialized squads use mixed
    return "Universal"

def main():
    role_dir = "docs/job_roles"
    output_dir = "docs/interview_questions"

    # We DO NOT skip files anymore. We overwrite everything to ensure consistency and coverage.

    for root, dirs, files in os.walk(role_dir):
        for file in files:
            if file.endswith(".md") and file != "JOB_ROLE_ORGANIZATION.md":
                role_path = os.path.join(root, file)
                rel_dir = os.path.relpath(root, role_dir)

                # Cleanup directory name: lowercase and single underscore
                rel_dir = rel_dir.lower().replace("__", "_")

                # Determine Category
                category = get_role_category(os.path.join(rel_dir, file))

                # Just use filename as role name
                role_name = file.replace(".md", "")
                role_code = "ROLE" # Placeholder

                # Cleanup filename: lowercase and single underscore
                clean_filename = file.lower().replace("__", "_")

                questions = get_question_bank(category, 100)

                # Ensure output directory exists
                target_dir = os.path.join(output_dir, rel_dir)
                os.makedirs(target_dir, exist_ok=True)

                target_file = os.path.join(target_dir, clean_filename)

                markdown = generate_markdown(role_name, role_code, questions)

                with open(target_file, 'w') as f:
                    f.write(markdown)

                print(f"Generated {target_file}")

if __name__ == "__main__":
    main()
