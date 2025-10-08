import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [buildInfo, setBuildInfo] = useState({
    version: '1.0.0',
    buildDate: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  const challenges = [
    {
      title: 'Challenge 1: Installation of ELK via Terraform',
      completed: true,
      description: 'Successfully deployed ELK stack using Infrastructure as Code'
    },
    {
      title: 'Challenge 2: Using CI/CD tools with ELK via Terraform',
      completed: true,
      description: 'Integrated GitLab CI/CD pipeline with ELK monitoring'
    },
    {
      title: 'Challenge 3: React Frontend Integration',
      completed: true,
      description: 'Built and deployed React application through pipeline'
    }
  ];

  const services = [
    { name: 'Kibana', port: '5601', status: 'running' },
    { name: 'GitLab', port: '8081', status: 'running' },
    { name: 'Tomcat', port: '8083', status: 'running' },
    { name: 'Elasticsearch', port: '9200', status: 'running' }
  ];

  return (
    <div className="App">
      <div className="container">
        <header className="app-header">
          <h1 className="title">Group 6</h1>
          <p className="subtitle">ELK Challenge - React Frontend</p>
          <div className="time-display">
            {currentTime.toLocaleString()}
          </div>
        </header>

        <section className="challenges-section">
          <h2>Project Challenges</h2>
          <div className="challenges-grid">
            {challenges.map((challenge, index) => (
              <div key={index} className="challenge-card">
                <div className="challenge-header">
                  <h3>{challenge.title}</h3>
                  <span className={`status ${challenge.completed ? 'completed' : 'pending'}`}>
                    {challenge.completed ? '✓' : '○'}
                  </span>
                </div>
                <p className="challenge-description">{challenge.description}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="services-section">
          <h2>Running Services</h2>
          <div className="services-grid">
            {services.map((service, index) => (
              <div key={index} className="service-card">
                <div className="service-name">{service.name}</div>
                <div className="service-port">Port: {service.port}</div>
                <div className={`service-status ${service.status}`}>
                  {service.status === 'running' ? '🟢' : '🔴'} {service.status}
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="build-info">
          <h3>Build Information</h3>
          <div className="build-details">
            <div>Version: {buildInfo.version}</div>
            <div>Environment: {buildInfo.environment}</div>
            <div>Build Date: {new Date(buildInfo.buildDate).toLocaleString()}</div>
          </div>
        </section>

        <footer className="app-footer">
          <p>Deployed via Terraform • Monitored with ELK Stack • Built with React</p>
        </footer>
      </div>
    </div>
  );
}

export default App;