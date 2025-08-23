# custom-ci-tool

## File Structure
```
/custom-ci-tool/
├── components/
│   ├── git-clone.sh
│   ├── build-image.sh
│   ├── push-image.sh
│   └── notify-slack.sh
├── build.sh                        # Main CLI entry point
├── projects/
│   ├── project-a/
│   │   ├── dev/
│   │   │   ├── build.conf         # Config per environment
│   │   │   └── pipeline.sh        # Project-specific pipeline using components
│   │   └── prod/
│   │       ├── build.conf  
│   │       └── pipeline.sh
│   └── project-b/
│       └── uat/
│           ├── build.conf
│           └── pipeline.sh
├── templates/
│   └── build-template.sh          # Starter template for new projects
├── builds/
│   └── logs/
│       └── <project>/<env>/       # Logs and diffs here
├── common/
│   └── functions.sh               # Shared utilities: log, diff, etc.
```
---

