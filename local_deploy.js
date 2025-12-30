#!/usr/bin/env node

const readline = require('readline');
const { spawn, execSync } = require('child_process');
const crypto = require('crypto');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const askQuestion = (query, defaultValue) => {
    return new Promise((resolve) => {
        rl.question(`${query} ${defaultValue ? `(${defaultValue})` : ''}: `, (answer) => {
            resolve(answer.trim() || defaultValue);
        });
    });
};

const generateKeyFileContent = () => {
    return crypto.randomBytes(756).toString('base64');
};

const main = async () => {
    console.log("--- Infra Local Deploy ---");

    const username = await askQuestion("Enter MongoDB Username", "admin");
    const password = await askQuestion("Enter MongoDB Password", "admin");

    const currentContext = execSync('docker context show').toString().trim();
    const changeContext = await askQuestion(`Do you want to change docker context? (Current: ${currentContext}) (y/n)`, "n");

    if (changeContext.toLowerCase() === 'y') {
        try {
            const contexts = execSync('docker context ls --format "{{.Name}}"').toString().trim().split('\n');
            console.log("\nAvailable contexts:");
            contexts.forEach((ctx, idx) => console.log(`${idx + 1}. ${ctx}`));

            const contextIndex = await askQuestion("Select context number", "1");
            const selectedContext = contexts[parseInt(contextIndex) - 1];

            if (selectedContext) {
                console.log(`Switching to context: ${selectedContext}`);
                execSync(`docker context use ${selectedContext}`, { stdio: 'inherit' });
            } else {
                console.log("Invalid context selection. Continuing with current context.");
            }
        } catch (error) {
            console.error("Failed to list or switch contexts:", error.message);
        }
    }

    console.log("\nGenerating MongoDB Replica Set Key...");
    const keyContent = generateKeyFileContent();

    console.log("Deploying stack...");

    const mongoRsUri = `mongodb://${username}:${password}@mongo-rs-1:27017/?replicaSet=rs0`;

    const env = {
        ...process.env,
        MONGO_RS_ROOT_USERNAME: username,
        MONGO_RS_ROOT_PASSWORD: password,
        MONGO_VIEWER_USER: username,
        MONGO_VIEWER_PASS: password,
        MONGO_RS_KEYFILE_CONTENT: keyContent,
        MONGO_RS_URI: mongoRsUri
    };

    console.log("\nDeploying stack...");
    console.log("Mongo URI: ", mongoRsUri);

    const deployProcess = spawn('docker', ['stack', 'deploy', '-c', 'docker-stack.local.yml', 'infra'], {
        env: env,
        stdio: 'inherit'
    });

    deployProcess.on('close', (code) => {
        rl.close();
        if (code === 0) {
            console.log("\nDeployment successful!");
            console.log(`Mongo Viewer available at: http://<docker vm ip>:5000`);
        } else {
            console.error(`\nDeployment failed with code ${code}`);
            process.exit(code);
        }
    });
};

main();
