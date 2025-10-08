# Group 6 React Application

A React.js frontend application for the ELK Challenge project, designed to work with GitLab CI/CD pipeline and Terraform infrastructure.

## Features

- **Real-time Clock**: Shows current date and time
- **Challenge Status**: Displays completed project challenges
- **Service Monitoring**: Shows status of running services
- **Build Information**: Displays version, environment, and build details
- **Responsive Design**: Works on desktop and mobile devices

## Services Integration

This app is designed to work with the following services deployed via Terraform:

- **Kibana** (Port 5601): ELK Stack visualization
- **GitLab** (Port 8081): CI/CD platform
- **Tomcat** (Port 8083): Application server
- **Elasticsearch** (Port 9200): Search and analytics engine

## Development

### Prerequisites

- Node.js 16 or higher
- npm or yarn

### Local Development

```bash
# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build

# Run tests
npm test
```

## CI/CD Pipeline

This application is designed to be deployed through GitLab CI/CD pipeline:

1. **Build Stage**: Compiles React application
2. **Test Stage**: Runs unit tests
3. **Deploy Stage**: Deploys to Tomcat server
4. **Monitor Stage**: Integrates with ELK stack for logging

## Deployment

The built application can be deployed to:

- **Tomcat Server**: As a WAR file
- **Static Web Server**: As static files
- **Docker Container**: Using multi-stage builds

## Monitoring

Application integrates with ELK stack for:

- **Application Logs**: Sent to Logstash
- **Performance Metrics**: Visualized in Kibana
- **Error Tracking**: Indexed in Elasticsearch

## Technologies Used

- React 18
- Modern CSS with Grid and Flexbox
- ES6+ JavaScript features
- Responsive design principles

## Project Structure

```
group6-react-app/
├── public/
│   └── index.html
├── src/
│   ├── App.js
│   ├── App.css
│   ├── index.js
│   └── index.css
├── package.json
└── README.md
```

## Build and Deployment

The application builds to static files that can be served by any web server or integrated into existing Java web applications as static resources.