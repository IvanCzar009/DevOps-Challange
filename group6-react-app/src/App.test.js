import { render, screen } from '@testing-library/react';
import App from './App';

test('renders Group 6 title', () => {
  render(<App />);
  const titleElement = screen.getByText(/Group 6/i);
  expect(titleElement).toBeInTheDocument();
});

test('renders ELK Challenge subtitle', () => {
  render(<App />);
  const subtitleElement = screen.getByText(/ELK Challenge - React Frontend/i);
  expect(subtitleElement).toBeInTheDocument();
});

test('renders challenge cards', () => {
  render(<App />);
  const challenge1 = screen.getByText(/Installation of ELK via Terraform/i);
  const challenge2 = screen.getByText(/Using CI\/CD tools with ELK via Terraform/i);
  const challenge3 = screen.getByText(/React Frontend Integration/i);
  
  expect(challenge1).toBeInTheDocument();
  expect(challenge2).toBeInTheDocument();
  expect(challenge3).toBeInTheDocument();
});

test('renders service cards', () => {
  render(<App />);
  const kibanaService = screen.getByText(/Kibana/i);
  const gitlabService = screen.getByText(/GitLab/i);
  const tomcatService = screen.getByText(/Tomcat/i);
  const elasticsearchService = screen.getByText(/Elasticsearch/i);
  
  expect(kibanaService).toBeInTheDocument();
  expect(gitlabService).toBeInTheDocument();
  expect(tomcatService).toBeInTheDocument();
  expect(elasticsearchService).toBeInTheDocument();
});

test('renders build information', () => {
  render(<App />);
  const buildInfo = screen.getByText(/Build Information/i);
  const version = screen.getByText(/Version: 1\.0\.0/i);
  
  expect(buildInfo).toBeInTheDocument();
  expect(version).toBeInTheDocument();
});