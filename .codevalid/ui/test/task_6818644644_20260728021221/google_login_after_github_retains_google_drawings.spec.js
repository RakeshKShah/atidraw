import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockGithubAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  googleDrawingsResponse,
  githubDrawingsResponse,
} from "../../mock/mock-data.js";

test("Switching from GitHub to Google login retains drawings for each identity", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "google_login_after_github_retains_google_drawings",
    testTitle: testInfo.title,
  });

  await recorder.step("Load GitHub drawings and verify GitHub-only visibility");
  await mockGithubAuthenticatedSession(page);
  await mockDrawingsList(page, githubDrawingsResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toBeVisible();
  await expect(page.getByText("GitHub User")).toBeVisible();
  await expect(page.getByRole("img", { name: "Google drawing" })).toHaveCount(0);

  await recorder.step("Switch to Google login and verify Google-only visibility");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, googleDrawingsResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toHaveCount(0);
  await expect(page.getByText("GitHub User")).toHaveCount(0);

  await recorder.step("Switch back to GitHub and verify the GitHub set still persists independently");
  await mockGithubAuthenticatedSession(page);
  await mockDrawingsList(page, githubDrawingsResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toBeVisible();
  await expect(page.getByText("GitHub User")).toBeVisible();
  await expect(page.getByRole("img", { name: "Google drawing" })).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:google_login_after_github_retains_google_drawings");
  await recorder.save(testInfo);
});
